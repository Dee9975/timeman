local M = {}

local config = require("timeman.config")

function M.setup(opts)
  config.set(opts)
end

return M
