--- httpyac-nvim session module
--- Manages the Node.js sidecar process that keeps httpyac state alive.
---
--- The sidecar reads newline-delimited JSON commands from stdin and writes
--- newline-delimited JSON responses to stdout.  All state (cookies, $global
--- variables, OAuth tokens) persists for the lifetime of the sidecar process,
--- i.e. for the current Neovim session.

local M = {}

local uv = vim.uv

-- Resolve the sidecar script path relative to this Lua file.
local script_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
local SIDECAR = script_dir .. "session-server.js"

-- Process state -- all fields are reset when the sidecar dies or is stopped.
local proc = {
	handle  = nil, -- uv process handle
	stdin   = nil, -- uv pipe (write to sidecar)
	stdout  = nil, -- uv pipe (read from sidecar)
	stderr  = nil, -- uv pipe (drain / discard)
	buffer  = "",  -- incomplete stdout data waiting for '\n'
	pending = {},  -- FIFO queue of callbacks, one per in-flight command
}

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

local function reset_proc()
	proc.handle  = nil
	proc.stdin   = nil
	proc.stdout  = nil
	proc.stderr  = nil
	proc.buffer  = ""
	proc.pending = {}
end

--- Pop the front pending callback and call it with the parsed response.
local function process_line(line)
	local cb = table.remove(proc.pending, 1)
	if not cb then
		vim.schedule(function()
			vim.notify(
				"httpyac-session: unexpected response (no pending callback): " .. line,
				vim.log.levels.WARN
			)
		end)
		return
	end

	local ok, parsed = pcall(vim.json.decode, line)
	if ok then
		vim.schedule(function() cb(parsed) end)
	else
		vim.schedule(function()
			cb({ ok = false, error = "JSON parse error: " .. tostring(parsed), output = "" })
		end)
	end
end

--- Drain proc.buffer, calling process_line for each complete '\n'-terminated line.
local function consume_buffer()
	while true do
		local nl = proc.buffer:find("\n", 1, true)
		if not nl then break end
		local line = proc.buffer:sub(1, nl - 1)
		proc.buffer = proc.buffer:sub(nl + 1)
		if line ~= "" then
			process_line(line)
		end
	end
end

-- ---------------------------------------------------------------------------
-- ensure_running() — start the sidecar if it is not already alive.
-- Returns true on success, false on failure.
-- ---------------------------------------------------------------------------
local function ensure_running()
	if proc.handle and not proc.handle:is_closing() then
		return true
	end

	reset_proc()

	if vim.fn.executable("node") == 0 then
		vim.notify(
			"httpyac-session: 'node' executable not found in PATH",
			vim.log.levels.ERROR
		)
		return false
	end

	local stdin_pipe  = uv.new_pipe(false)
	local stdout_pipe = uv.new_pipe(false)
	local stderr_pipe = uv.new_pipe(false)

	local handle, _pid = uv.spawn("node", {
		args  = { SIDECAR },
		stdio = { stdin_pipe, stdout_pipe, stderr_pipe },
	}, function(code, _signal)
		-- Sidecar exited — clean up pipes.
		if stdin_pipe  and not stdin_pipe:is_closing()  then stdin_pipe:close()  end
		if stdout_pipe and not stdout_pipe:is_closing() then stdout_pipe:close() end
		if stderr_pipe and not stderr_pipe:is_closing() then stderr_pipe:close() end

		vim.schedule(function()
			-- Drain any pending callbacks with an error so Lua callers don't hang.
			local pending = proc.pending
			reset_proc()
			for _, cb in ipairs(pending) do
				cb({
					ok    = false,
					error = "Session sidecar exited (code=" .. tostring(code) .. ")",
					output = "",
				})
			end
			if code ~= 0 then
				vim.notify(
					"httpyac-session: sidecar exited with code " .. tostring(code),
					vim.log.levels.WARN
				)
			end
		end)
	end)

	if not handle then
		vim.notify("httpyac-session: failed to spawn sidecar process", vim.log.levels.ERROR)
		if stdin_pipe  and not stdin_pipe:is_closing()  then stdin_pipe:close()  end
		if stdout_pipe and not stdout_pipe:is_closing() then stdout_pipe:close() end
		if stderr_pipe and not stderr_pipe:is_closing() then stderr_pipe:close() end
		return false
	end

	proc.handle = handle
	proc.stdin  = stdin_pipe
	proc.stdout = stdout_pipe
	proc.stderr = stderr_pipe

	-- Stream stdout — data may arrive in multiple chunks; buffer until '\n'.
	stdout_pipe:read_start(function(err, data)
		if err then
			vim.schedule(function()
				vim.notify(
					"httpyac-session: stdout read error: " .. tostring(err),
					vim.log.levels.ERROR
				)
			end)
			return
		end
		if data then
			proc.buffer = proc.buffer .. data
			consume_buffer()
		end
	end)

	-- Drain stderr silently so it doesn't surface in the terminal.
	stderr_pipe:read_start(function(_err, _data) end)

	return true
end

-- ---------------------------------------------------------------------------
-- send_cmd(cmd_table, callback)
-- Serialise cmd as JSON, push callback onto the pending queue, write to stdin.
-- ---------------------------------------------------------------------------
local function send_cmd(cmd, cb)
	if not ensure_running() then
		vim.schedule(function()
			cb({ ok = false, error = "Sidecar not running", output = "" })
		end)
		return
	end

	table.insert(proc.pending, cb)

	local line = vim.json.encode(cmd) .. "\n"
	proc.stdin:write(line, function(err)
		if err then
			vim.schedule(function()
				vim.notify(
					"httpyac-session: stdin write error: " .. tostring(err),
					vim.log.levels.ERROR
				)
			end)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Send the HTTP request at a specific file + cursor line.
--- @param file  string      Absolute path to the .http file.
--- @param line  number      1-indexed cursor line (Neovim convention).
--- @param env   string|nil  Environment identifier, e.g. "dev".
--- @param cb    function    Callback: cb(response_table).
M.send_request = function(file, line, env, cb)
	send_cmd({
		type = "send",
		file = file,
		line = line,
		env  = env or vim.NIL,
	}, cb)
end

--- Send all HTTP requests in a file.
--- @param file  string      Absolute path to the .http file.
--- @param env   string|nil  Environment identifier.
--- @param cb    function    Callback: cb(response_table).
M.send_all = function(file, env, cb)
	send_cmd({
		type = "send",
		file = file,
		all  = true,
		env  = env or vim.NIL,
	}, cb)
end

--- Reset session state: clears $global variables, cookies, and OAuth tokens.
M.reset_session = function()
	send_cmd({ type = "reset" }, function(r)
		vim.notify(
			r.ok and "httpyac: Session reset" or ("httpyac: Reset failed: " .. (r.error or "")),
			r.ok and vim.log.levels.INFO or vim.log.levels.ERROR
		)
	end)
end

--- Query the current $global variables and pass them to a callback.
--- @param env string|nil  Environment identifier.
--- @param cb  function    Callback: cb(response_table).
M.get_vars = function(env, cb)
	send_cmd({ type = "vars", env = env or vim.NIL }, cb)
end

--- Show the current $global variables in a floating window.
M.show_globals = function()
	send_cmd({ type = "vars" }, function(r)
		if not r.ok then
			vim.notify(
				"httpyac: Failed to read globals: " .. (r.error or ""),
				vim.log.levels.ERROR
			)
			return
		end

		local count = 0
		if r.globals then
			for _ in pairs(r.globals) do count = count + 1 end
		end

		if count == 0 then
			vim.notify("httpyac: No session globals set ($global is empty)", vim.log.levels.INFO)
			return
		end

		-- Show in a floating scratch buffer.
		local lines = { "# Session Globals (" .. count .. " var(s))", "" }
		if r.output and r.output ~= "" then
			for _, l in ipairs(vim.split(r.output, "\n")) do
				table.insert(lines, l)
			end
		end

		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.api.nvim_set_option_value("filetype",  "json",  { buf = buf })
		vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

		local width  = math.min(80, vim.o.columns - 4)
		local height = math.min(#lines + 2, vim.o.lines - 4)
		vim.api.nvim_open_win(buf, true, {
			relative  = "editor",
			width     = width,
			height    = height,
			row       = math.floor((vim.o.lines   - height) / 2),
			col       = math.floor((vim.o.columns - width)  / 2),
			style     = "minimal",
			border    = "rounded",
			title     = " Session Globals ",
			title_pos = "center",
		})
		vim.keymap.set("n", "q", "<cmd>close<cr>", {
			buffer  = buf,
			noremap = true,
			silent  = true,
			desc    = "Close globals window",
		})
	end)
end

--- Kill the sidecar process cleanly.
M.stop = function()
	if proc.handle and not proc.handle:is_closing() then
		proc.handle:kill(15) -- SIGTERM
	end
	reset_proc()
end

--- Check whether the sidecar is currently running.
--- @return boolean
M.is_running = function()
	return proc.handle ~= nil and not proc.handle:is_closing()
end

return M
