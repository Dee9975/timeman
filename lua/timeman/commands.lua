local db = require("timeman.db")

local M = {}

function M.register()
  vim.api.nvim_create_user_command("TimemanList", function()
    require("timeman.float").open()
  end, {
    desc = "Show all timeman tasks in a floating window",
  })

  vim.api.nvim_create_user_command("TimemanTasks", function()
    require("timeman.telescope").tasks()
  end, {
    desc = "Browse timeman tasks with Telescope",
  })

  local function create_task(name)
    local ok, err = pcall(db.add_task, name)
    if ok then
      vim.notify("timeman: created task '" .. name .. "'")
    else
      vim.notify("timeman: " .. tostring(err), vim.log.levels.ERROR)
    end
  end

  vim.api.nvim_create_user_command("TimemanCreateTask", function(opts)
    local name = vim.trim(opts.args)
    if name == "" then
      vim.ui.input({ prompt = "Task name: " }, function(input)
        if not input then return end
        name = vim.trim(input)
        if name == "" then
          vim.notify("timeman: task name is required", vim.log.levels.ERROR)
          return
        end
        create_task(name)
      end)
    else
      create_task(name)
    end
  end, {
    nargs = "*",
    desc = "Create a new timeman task",
  })
end

return M
