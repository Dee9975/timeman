local db = require("timeman.db")

local M = {}

local function format_time(seconds)
  if seconds == 0 then return nil end
  local h = math.floor(seconds / 3600)
  local m = math.floor((seconds % 3600) / 60)
  if h > 0 then return string.format("%dh %dm", h, m) end
  return string.format("%dm", m)
end

local function date_sort_key(date_str)
  local d, mo, y = date_str:match("^(%d%d)-(%d%d)-(%d%d%d%d)$")
  if not d then return date_str end
  return y .. mo .. d
end

-- Returns lines and a table mapping 1-indexed line number → task
local function build_lines(tasks)
  local groups = {}
  for _, s in ipairs(db.statuses) do groups[s] = {} end

  for _, task in ipairs(tasks) do
    local bucket = groups[task.status] or groups["todo"]
    table.insert(bucket, task)
  end

  for _, bucket in pairs(groups) do
    table.sort(bucket, function(a, b)
      return date_sort_key(a.created_at) < date_sort_key(b.created_at)
    end)
  end

  local lines = {}
  local line_to_task = {}
  local headings = { "in progress", "todo", "done" }

  for _, status in ipairs(headings) do
    local bucket = groups[status]
    local heading = status:gsub("^%l", string.upper)
    table.insert(lines, heading)
    table.insert(lines, string.rep("─", 40))

    if #bucket == 0 then
      table.insert(lines, "  (none)")
    else
      for _, task in ipairs(bucket) do
        local time = format_time(task.total_time)
        local suffix = time and ("  [" .. time .. "]") or ""
        table.insert(lines, "  · " .. task.name .. "  " .. task.created_at .. suffix)
        line_to_task[#lines] = task
      end
    end

    table.insert(lines, "")
  end

  if lines[#lines] == "" then table.remove(lines) end

  return lines, line_to_task
end

local function find_task_line(from, dir, line_to_task, total)
  local i = from + dir
  for _ = 1, total do
    if i > total then i = 1 end
    if i < 1 then i = total end
    if line_to_task[i] then return i end
    i = i + dir
  end
end

function M.open()
  local tasks = db.get_tasks()
  local lines, line_to_task = build_lines(tasks)

  local width = math.min(70, vim.o.columns - 4)
  local height = math.min(#lines + 2, vim.o.lines - 4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "timeman"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Timeman ",
    title_pos = "center",
  })
  vim.wo[win].wrap = false

  -- Place cursor on first task line
  local first = find_task_line(0, 1, line_to_task, #lines)
  if first then vim.api.nvim_win_set_cursor(win, { first, 2 }) end

  local function refresh(keep_near)
    tasks = db.get_tasks()
    lines, line_to_task = build_lines(tasks)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    -- land on the nearest task line to where we were
    local target = find_task_line(keep_near - 1, 1, line_to_task, #lines)
      or find_task_line(keep_near + 1, -1, line_to_task, #lines)
    if target then vim.api.nvim_win_set_cursor(win, { target, 2 }) end
  end

  local function move(dir)
    local cur = vim.api.nvim_win_get_cursor(win)[1]
    local dest = find_task_line(cur, dir, line_to_task, #lines)
    if dest then vim.api.nvim_win_set_cursor(win, { dest, 2 }) end
  end

  local function set_status(status)
    local cur = vim.api.nvim_win_get_cursor(win)[1]
    local task = line_to_task[cur]
    if not task then return end
    db.set_status(task.id, status)
    refresh(cur)
  end

  local function create_task()
    local cur = vim.api.nvim_win_get_cursor(win)[1]
    vim.ui.input({ prompt = "Task name: " }, function(input)
      if not input then return end
      local name = vim.trim(input)
      if name == "" then
        vim.notify("timeman: task name is required", vim.log.levels.ERROR)
        return
      end
      local ok, err = pcall(db.add_task, name)
      if ok then
        refresh(cur)
      else
        vim.notify("timeman: " .. tostring(err), vim.log.levels.ERROR)
      end
    end)
  end

  local function delete_task()
    local cur = vim.api.nvim_win_get_cursor(win)[1]
    local task = line_to_task[cur]
    if not task then return end

    local choice = vim.fn.confirm("Delete task '" .. task.name .. "'?", "&Yes\n&No", 2)
    if choice == 1 then
      db.delete_task(task.id)
      refresh(cur)
    end
  end

  local opts = { buffer = buf, nowait = true }

  for _, key in ipairs({ "j", "<Down>" }) do
    vim.keymap.set("n", key, function() move(1) end, opts)
  end
  for _, key in ipairs({ "k", "<Up>" }) do
    vim.keymap.set("n", key, function() move(-1) end, opts)
  end

  vim.keymap.set("n", "p",      function() set_status("in progress") end, opts)
  vim.keymap.set("n", "<CR>",   function() set_status("done") end, opts)
  vim.keymap.set("n", "d",      delete_task, opts)
  vim.keymap.set("n", "n",      create_task, opts)
  vim.keymap.set("n", "<S-CR>", function() set_status("done") end, opts)
  vim.keymap.set("n", "t",      function() set_status("todo") end, opts)

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, "<cmd>close<cr>", opts)
  end
end

return M
