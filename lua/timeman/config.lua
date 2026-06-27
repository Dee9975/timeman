local M = {}

M.defaults = {}

M.options = {}

function M.set(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
