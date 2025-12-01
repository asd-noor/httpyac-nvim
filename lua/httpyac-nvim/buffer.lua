local M = {}

M.open_readonly_vsplit = function(bufname, bufnr)
	local bnr = -1
	if bufnr and type(bufnr) == "number" and vim.api.nvim_buf_is_valid(bufnr) then
		bnr = bufnr
	end

	local bname = bufname or "READONLY"
	-- Get a boolean that tells us if the buffer number is visible anymore.
	-- :help bufwinnr
	local buffer_visible = vim.api.nvim_call_function("bufwinnr", { bnr }) ~= -1

	if bnr == -1 or not buffer_visible then
		-- Create a new buffer with the name "HTTPYAC_OUT".
		-- Same name will reuse the current buffer.
		vim.api.nvim_command("botright vsplit " .. bname)

		-- Collect the buffer's number.
		local robufnr = vim.api.nvim_get_current_buf()

		-- Mark the buffer as readonly.
		vim.opt_local.readonly = true
		return robufnr
	end

	-- Return the existing buffer number
	return bnr
end

M.update_readonly_buffer = function(filetype, bufnr, data)
	if not bufnr or type(bufnr) ~= "number" then
		vim.notify("Buffer number is required to update readonly buffer", vim.log.levels.ERROR)
		return
	end

	local ft = filetype or "readonlybuf"
	local bnr = bufnr or -1
	if data then
		-- Append the data.
		vim.api.nvim_set_option_value("readonly", false, { buf = bnr })
		vim.api.nvim_buf_set_text(bufnr, 0, 0, -1, -1, vim.split(data, "\n"))
		vim.api.nvim_set_option_value("readonly", true, { buf = bnr })
		-- Mark as not modified, otherwise you'll get an error when attempting to exit vim.
		vim.api.nvim_set_option_value("modified", false, { buf = bnr })
		-- set httpResult ft for syntax highlighting
		vim.api.nvim_set_option_value("filetype", ft, { buf = bnr })

		-- Get the window the buffer is in and set the cursor position to the top.
		local buffer_window = vim.api.nvim_call_function("bufwinid", { bnr })
		vim.api.nvim_win_set_cursor(buffer_window, { 1, 0 })
	end
end

return M
