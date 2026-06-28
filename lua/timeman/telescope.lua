local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local db = require("timeman.db")

local M = {}

local function format_time(seconds)
  local h = math.floor(seconds / 3600)
  local m = math.floor((seconds % 3600) / 60)
  if h > 0 then
    return string.format("%dh %dm", h, m)
  end
  return string.format("%dm", m)
end

local function entry_display(task)
  local time = task.total_time > 0 and (" [" .. format_time(task.total_time) .. "]") or ""
  local desc = task.description and (" — " .. task.description) or ""
  return string.format("[%s]%s %s%s", task.status, time, task.name, desc)
end

function M.tasks(opts)
  opts = opts or {}
  pickers.new(opts, {
    prompt_title = "Timeman Tasks",
    finder = finders.new_dynamic({
      fn = function()
        return db.get_tasks()
      end,
      entry_maker = function(task)
        return {
          value = task,
          display = entry_display(task),
          ordinal = task.name .. " " .. (task.description or "") .. " " .. task.status,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local task = action_state.get_selected_entry().value
        db.set_status(task.id, "in progress")
        vim.notify("timeman: started tracking '" .. task.name .. "'")
      end)
      return true
    end,
  }):find()
end

return M
