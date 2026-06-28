local M = {}

M.statuses = { "todo", "in progress", "done" }

local root = nil

local function today()
  return os.date("%d-%m-%Y")
end

local function sanitize(name)
  return name:gsub("[/\\]", "-")
end

local function read_lines(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local lines = {}
  for line in f:lines() do
    table.insert(lines, line)
  end
  f:close()
  return lines
end

local function parse_file(path, name, date)
  local lines = read_lines(path)
  if not lines then return nil end

  local meta = {}
  local desc_lines = {}
  local i = 1

  if lines[i] == "---" then
    i = i + 1
    while i <= #lines and lines[i] ~= "---" do
      local key, val = lines[i]:match("^([%w_]+):%s*(.-)%s*$")
      if key then meta[key] = val end
      i = i + 1
    end
    i = i + 1 -- skip closing ---
  end

  -- skip leading blank line after frontmatter
  if lines[i] == "" then i = i + 1 end

  for j = i, #lines do
    table.insert(desc_lines, lines[j])
  end

  -- trim trailing blank lines
  while desc_lines[#desc_lines] == "" do
    table.remove(desc_lines)
  end

  local status = meta.status or "todo"
  local total_time = tonumber(meta.total_time) or 0
  local last_changed = tonumber(meta.last_changed)
  local parsed_at = os.time()

  if status == "in progress" and last_changed then
    local elapsed = parsed_at - last_changed
    if elapsed > 0 then
      total_time = total_time + elapsed
    end
  end

  return {
    id = path,
    name = name,
    description = #desc_lines > 0 and table.concat(desc_lines, "\n") or nil,
    status = status,
    total_time = total_time,
    last_changed = last_changed,
    parsed_at = parsed_at,
    created_at = date,
  }
end

local function write_file(path, task)
  local f = io.open(path, "w")
  if not f then error("timeman: cannot write " .. path) end
  f:write("---\n")
  f:write("status: " .. (task.status or "todo") .. "\n")

  local total_time = task.total_time or 0
  local last_changed = nil

  if task.status == "in progress" then
    local now = os.time()
    last_changed = now
    if task.parsed_at then
      local elapsed_since_parse = now - task.parsed_at
      if elapsed_since_parse > 0 then
        total_time = total_time + elapsed_since_parse
      end
    end
  end

  f:write("total_time: " .. tostring(total_time) .. "\n")
  if last_changed then
    f:write("last_changed: " .. tostring(last_changed) .. "\n")
  end
  f:write("---\n")
  if task.description and task.description ~= "" then
    f:write("\n" .. task.description .. "\n")
  end
  f:close()
end

function M.open(path)
  root = path
end

function M.add_task(name, description)
  local date = today()
  local dir = root .. "/" .. date
  vim.fn.mkdir(dir, "p")
  local path = dir .. "/" .. sanitize(name)
  write_file(path, { status = "todo", total_time = 0, description = description })
  return path
end

function M.get_tasks()
  local result = {}
  for _, dir in ipairs(vim.fn.glob(root .. "/*", false, true)) do
    if vim.fn.isdirectory(dir) == 1 then
      local date = vim.fn.fnamemodify(dir, ":t")
      if date:match("^%d%d%-%d%d%-%d%d%d%d$") then
        for _, file in ipairs(vim.fn.glob(dir .. "/*", false, true)) do
          if vim.fn.isdirectory(file) == 0 then
            local name = vim.fn.fnamemodify(file, ":t")
            local task = parse_file(file, name, date)
            if task then table.insert(result, task) end
          end
        end
      end
    end
  end
  return result
end

function M.get_task(id)
  local date = vim.fn.fnamemodify(vim.fn.fnamemodify(id, ":h"), ":t")
  local name = vim.fn.fnamemodify(id, ":t")
  return parse_file(id, name, date)
end

function M.add_time(id, seconds)
  local task = M.get_task(id)
  if not task then return end
  task.total_time = task.total_time + seconds
  write_file(id, task)
end

function M.stop_timer()
  -- No-op: file-based tracking is stateless and updates dynamically
end

function M.start_timer(id)
  -- No-op: handled by setting task status to "in progress"
end

function M.set_status(id, status)
  assert(vim.tbl_contains(M.statuses, status), "invalid status: " .. tostring(status))
  local task = M.get_task(id)
  if not task then return end

  if status == "in progress" then
    for _, t in ipairs(M.get_tasks()) do
      if t.status == "in progress" and t.id ~= id then
        M.set_status(t.id, "todo")
      end
    end
  end

  task = M.get_task(id)
  if task then
    task.status = status
    write_file(id, task)
  end
end

function M.delete_task(id)
  vim.fn.delete(id)
end

return M
