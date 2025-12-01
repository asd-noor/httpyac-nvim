local M = {}

local P = require("snacks.picker")
local B = require("httpyac-nvim.buffer")

M.envfile = vim.env.HTTPYAC_ENV or ""
M.outputbufnr = nil
M.outputbufname = "HTTPYAC_OUT"
M.outputft = "httpyacout"

---@diagnostic disable-next-line: undefined-field
local uv = vim.uv

local exec_httpyac = function(opts)
	if vim.fn.executable("httpyac") == 0 then
		vim.notify("httpyac is not installed or not found in PATH", vim.log.levels.ERROR)
		return
	end

	-- Build args table for spawn
	local args = {}
	for _, arg in pairs(opts) do
		for word in arg:gmatch("%S+") do
			table.insert(args, word)
		end
	end

	if M.envfile ~= nil and M.envfile ~= "" then
		table.insert(args, "--env")
		table.insert(args, M.envfile)

		vim.notify("HTTPYAC: Using Custom Environment: " .. M.envfile, vim.log.levels.INFO)
	end

	-- create a tmp copy of the file
	local tmp_file_path = vim.fn.expand("%:p:h") .. "/.tmp_httpyac_" .. vim.fn.expand("%:t")
	-- save current buffer
	vim.api.nvim_command("w! " .. tmp_file_path)

	-- Insert tmp file path at the beginning of args
	table.insert(args, 1, tmp_file_path)

	-- open split buffer and always update the buffer number
	M.outputbufnr = B.open_readonly_vsplit(M.outputbufname, M.outputbufnr)

	-- Create pipes for stdout and stderr
	---@diagnostic disable-next-line: undefined-field
	local stdout = uv.new_pipe(false)
	---@diagnostic disable-next-line: undefined-field
	local stderr = uv.new_pipe(false)

	-- Accumulate output chunks
	local stdout_chunks = {}
	local stderr_chunks = {}

	-- Declare handle variable before spawn
	local handle

	-- Spawn httpyac process asynchronously
	---@diagnostic disable-next-line: undefined-field
	handle, _ = uv.spawn("httpyac", {
		args = args,
		stdio = { nil, stdout, stderr },
	}, function(code, signal)
		-- On exit callback
		if stdout and not stdout:is_closing() then
			stdout:close()
		end
		if stderr and not stderr:is_closing() then
			stderr:close()
		end
		if handle and not handle:is_closing() then
			handle:close()
		end

		-- Combine output
		local out = table.concat(stdout_chunks)
		local err_output = table.concat(stderr_chunks)
		local full_output = out
		if err_output ~= "" then
			full_output = full_output .. "\n--- STDERR ---\n" .. err_output
		end

		-- Schedule buffer log and cleanup in main thread
		vim.schedule(function()
			-- Clean up tmp file
			vim.fn.delete(tmp_file_path)
			B.update_readonly_buffer(M.outputft, M.outputbufnr, full_output)
		end)
	end)

	if not handle then
		vim.notify("Failed to spawn httpyac process", vim.log.levels.ERROR)
		vim.fn.delete(tmp_file_path)
		return
	end

	-- Read stdout asynchronously
	stdout:read_start(function(err, data)
		if err then
			vim.schedule(function()
				vim.notify("Error reading stdout: " .. err, vim.log.levels.ERROR)
			end)
		elseif data then
			table.insert(stdout_chunks, data)
		end
	end)

	-- Read stderr asynchronously
	stderr:read_start(function(err, data)
		if err then
			vim.schedule(function()
				vim.notify("Error reading stderr: " .. err, vim.log.levels.ERROR)
			end)
		elseif data then
			table.insert(stderr_chunks, data)
		end
	end)
end

M.set_custom_env = function()
	P.files({
		prompt = "Select HTTPYAC Environment File: ",
		confirm = function(picker, item)
			picker:close()
			if item and item.file then
				M.envfile = item.file
				vim.notify("HTTPYAC Environment set to: " .. M.envfile, vim.log.levels.INFO)
			else
				M.envfile = ""
				vim.notify("HTTPYAC Environment unset", vim.log.levels.INFO)
			end
		end,
	})
end

M.view_custom_env = function()
	if M.envfile == nil or M.envfile == "" then
		vim.notify("HTTPYAC: No custom environment set", vim.log.levels.INFO)
		return
	end

	vim.notify("Custom HTTPYAC Environment: " .. M.envfile, vim.log.levels.INFO)
end

M.send_request_at_cursor = function(opts)
	local o = opts or {}
	local curlineNumber = vim.api.nvim_win_get_cursor(0)[1]
	local args = { "-l " .. curlineNumber }
	args = vim.tbl_deep_extend("force", args, o)

	exec_httpyac(args)
end

M.send_buffer_requests = function(opts)
	local o = opts or {}
	local args = vim.tbl_deep_extend("force", { "-a" }, o)

	exec_httpyac(args)
end

return M
