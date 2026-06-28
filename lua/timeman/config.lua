local M = {}

M.defaults = {
  tasks_dir = nil, -- nil means use cwd at setup time
}

M.options = {}

function M.set(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
