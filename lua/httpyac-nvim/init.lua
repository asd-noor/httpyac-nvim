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

-- Session-mode functions
M.send_request_at_cursor_session = requtil.send_request_at_cursor_session
M.send_all_session               = requtil.send_all_session
M.reset_session                  = requtil.reset_session
M.show_session_globals           = requtil.show_session_globals
M.session_status                 = requtil.session_status

M.setup = function(opts)
	_ = opts or {}
	autocmd.register_keymaps()
end

return M
