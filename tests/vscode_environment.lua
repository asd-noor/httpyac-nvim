local decode = vim.json.decode
local root = "/tmp/httpyac-nvim-vscode-environment-test"

assert(os.execute("rm -rf " .. root .. " && mkdir -p " .. root .. "/api " .. root .. "/.vscode"))
local settings = assert(io.open(root .. "/.vscode/settings.json", "w"))
settings:write([[{
  "httpyac.environmentVariables": {
    "$shared": { "sharedKey": "shared" },
    "local": { "baseUrl": "http://localhost:8080", "name": "Ada" }
  }
}]])
settings:close()

local captured_args
local function pipe()
	return {
		is_closing = function() return false end,
		close = function() end,
		read_start = function() end,
	}
end

package.preload["snacks.picker"] = function() return {} end
package.preload["httpyac-nvim.buffer"] = function()
	return { open_readonly_vsplit = function() return 1 end, update_readonly_buffer = function() end }
end
package.preload["httpyac-nvim.session"] = function() return {} end

_G.vim = {
	env = {},
	NIL = {},
	json = { decode = decode },
	log = { levels = { ERROR = 1, INFO = 2 } },
	fn = {
		executable = function() return 1 end,
		expand = function(pattern)
			return pattern == "%:p:h" and root .. "/api" or "request.http"
		end,
		filereadable = function(path)
			local file = io.open(path, "r")
			if file then file:close() return 1 end
			return 0
		end,
		readfile = function(path)
			local file = assert(io.open(path, "r"))
			local lines = {}
			for line in file:lines() do table.insert(lines, line) end
			file:close()
			return lines
		end,
		fnamemodify = function(path, modifier)
			assert(modifier == ":h")
			return path:match("^(.*)/[^/]+$") or path
		end,
		delete = function() end,
	},
	api = {
		nvim_command = function() end,
		nvim_win_get_cursor = function() return { 6, 0 } end,
	},
	tbl_deep_extend = function(_, first) return first end,
	schedule = function(callback) callback() end,
	notify = function() end,
	uv = {
		new_pipe = pipe,
		spawn = function(_, options, callback)
			captured_args = options.args
			callback(0, 0)
			return pipe()
		end,
	},
}

local httpyac = dofile("lua/httpyac-nvim/httpyac.lua")
httpyac.envfile = "local"
httpyac.send_request_at_cursor()

local variables = {}
local environment
for index, argument in ipairs(captured_args) do
	if argument == "--var" then variables[captured_args[index + 1]] = true end
	if argument == "--env" then environment = captured_args[index + 1] end
end
assert(environment == "local")
assert(variables["sharedKey=shared"])
assert(variables["baseUrl=http://localhost:8080"])
assert(variables["name=Ada"])

assert(os.execute("rm -rf " .. root))
