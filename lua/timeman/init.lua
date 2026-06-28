local M = {}

local config = require("timeman.config")
local db = require("timeman.db")
local commands = require("timeman.commands")

function M.setup(opts)
  config.set(opts)
  local root = (config.options.tasks_dir or vim.fn.getcwd()) .. "/.timeman"
  vim.fn.mkdir(root, "p")
  db.open(root)
  commands.register()

  local group = vim.api.nvim_create_augroup("Timeman", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      db.stop_timer()
    end,
  })
end

return M
