local M = {}

local P = require("snacks.picker")

-- Common HTTP methods
local valid_methods = {
	GET = true,
	POST = true,
	PUT = true,
	PATCH = true,
	DELETE = true,
	HEAD = true,
	OPTIONS = true,
	CONNECT = true,
	TRACE = true,
	MQTT = true,
	GRPC = true,
	SSE = true,
	WS = true,
	AMQP = true,
}

M.get_http_requests = function()
	local requests = {}
	-- Match HTTP request lines: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS, etc.
	local pattern = "^%s*([A-Z]+)%s+(.+)%s*$"

	for line_num, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		local method, url = line:match(pattern)
		if method then
			if valid_methods[method] then
				requests[#requests + 1] = {
					value = method .. " " .. url,
					lnum = line_num,
				}
			end
		end
	end

	return requests
end

M.jump_to_request = function()
	local requests = M.get_http_requests()
	if #requests > 0 then
		P.select(requests, {
			prompt = "Jump to HTTP request: ",
			format_item = function(item)
				return item.value
			end,
		}, function(item)
			if item and item.lnum then
				vim.api.nvim_win_set_cursor(0, { item.lnum, 0 })
			end
		end)
	else
		print("No HTTP requests found in file.")
	end
end

M.get_http_variables = function()
	local variables = {}
	-- Match variable declarations: @variable_name = value
	local pattern = "^%s*@([%w_]+)%s*=%s*(.*)$"

	for line_num, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		local var_name, var_value = line:match(pattern)
		if var_name then
			variables[#variables + 1] = {
				value = "@" .. var_name .. " = " .. var_value,
				lnum = line_num,
			}
		end
	end

	return variables
end

M.jump_to_variable = function()
	local variables = M.get_http_variables()
	if #variables > 0 then
		P.select(variables, {
			prompt = "Jump to HTTP variable: ",
			format_item = function(item)
				return item.value
			end,
		}, function(item)
			if item and item.lnum then
				vim.api.nvim_win_set_cursor(0, { item.lnum, 0 })
			end
		end)
	else
		print("No HTTP variables found in file.")
	end
end

return M
