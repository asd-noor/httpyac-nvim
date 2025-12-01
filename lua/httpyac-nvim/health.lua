local M = {}

M.check = function()
	vim.health.start("httpyac-nvim")

	-- Check httpyac CLI
	if vim.fn.executable("httpyac") == 1 then
		local handle = io.popen("httpyac --version 2>&1")
		if handle then
			local version = handle:read("*a")
			handle:close()
			vim.health.ok("httpyac CLI found: " .. version:gsub("\n", ""))
		else
			vim.health.ok("httpyac CLI found (version check failed)")
		end
	else
		vim.health.error("httpyac CLI not found in PATH", {
			"Install httpyac: npm install -g httpyac",
			"Or: yarn global add httpyac",
		})
	end

	-- Check snacks.nvim dependency
	local ok, snacks = pcall(require, "snacks")
	if ok and snacks then
		vim.health.ok("snacks.nvim is available")
	else
		vim.health.error("snacks.nvim not found (required dependency)", {
			"Install snacks.nvim: https://github.com/folke/snacks.nvim",
		})
	end

	-- Check which-key dependency
	local ok_wk, which_key = pcall(require, "which-key")
	if ok_wk and which_key then
		vim.health.ok("which-key is available")
	else
		vim.health.error("which-key not found (required for keymaps)", {
			"Install which-key: https://github.com/folke/which-key.nvim",
		})
	end

	-- Check NeoVim version (needs 0.10+ for vim.uv)
	local version = vim.version()
	if version.major > 0 or (version.major == 0 and version.minor >= 10) then
		vim.health.ok("NeoVim version " .. vim.version().major .. "." .. vim.version().minor .. " (requires 0.10+)")
	else
		vim.health.error("NeoVim version too old: " .. vim.version().major .. "." .. vim.version().minor, {
			"httpyac-nvim requires NeoVim 0.10 or newer for vim.uv support",
		})
	end

	-- Check environment variable
	local env = vim.env.HTTPYAC_ENV
	if env and env ~= "" then
		vim.health.info("HTTPYAC_ENV set to: " .. env)
	else
		vim.health.info("HTTPYAC_ENV not set (optional)")
	end
end

return M
