local M = {}

local fileutil = require("httpyac-nvim.httpfile")
local requtil = require("httpyac-nvim.httpyac")
local autocmd = require("httpyac-nvim.autocmd")

M.jump_to_request = fileutil.jump_to_request
M.jump_to_variable = fileutil.jump_to_variable

M.set_custom_env = requtil.set_custom_env
M.view_custom_env = requtil.view_custom_env
M.send_request_at_cursor = requtil.send_request_at_cursor
M.send_all_requests = requtil.send_buffer_requests

M.setup = function(opts)
	_ = opts or {}
	autocmd.register_keymaps()
end

return M
