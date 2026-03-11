local M = {}

local newgroup = vim.api.nvim_create_augroup
local newautocmd = vim.api.nvim_create_autocmd

local httpyac = require("httpyac-nvim.httpyac")
local httputil = require("httpyac-nvim.httpfile")
local wk = require("which-key")

M.register_keymaps = function()
	newautocmd("FileType", {
		group = newgroup("HTTPFileKeymaps", { clear = true }),
		pattern = "http",
		callback = function(args)
			local b = args.buf
			wk.add({
				{ "<leader>R", group = "httpYac", icon = "🌐", buffer = b },
				{
					"<leader>Rs",
					httpyac.send_request_at_cursor,
					desc = "Send HTTP Request at Cursor",
					icon = "➡️",
					buffer = b,
				},
				{
					"<leader>RS",
					httpyac.send_buffer_requests,
					desc = "Send all HTTP Requests in file",
					icon = "📤",
					buffer = b,
				},
				{
					"<leader>Re",
					httpyac.view_custom_env,
					desc = "View HTTPYAC Environment",
					icon = "👁️",
					buffer = b,
				},
				{
					"<leader>RE",
					httpyac.set_custom_env,
					desc = "Set HTTPYAC Environment",
					icon = "⚙️",
					buffer = b,
				},
				{ "<leader>Rr", httputil.jump_to_request, desc = "HTTP Requests", buffer = b, icon = "🌐" },
				{ "<leader>Rv", httputil.jump_to_variable, desc = "HTTP Variables", buffer = b, icon = "🌐" },
			}, { buffer = b, noremap = true, silent = true })
		end,
	})

	newautocmd("FileType", {
		group = newgroup("HTTPYACOutKeymaps", { clear = true }),
		pattern = "httpyacout",
		callback = function(args)
			local b = args.buf
			vim.keymap.set("n", "x", httpyac.close_output, { buffer = b, noremap = true, silent = true, desc = "Close HTTPYAC output" })
		end,
	})
end

return M
