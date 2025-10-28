
local M = {}

fg_ctx = {
	cells = {},
}

local update_delay_ms = 8

function M.tile_create(win_id, buf_id, x, y)
	local tile = {
		win_id = win_id,
		buf_id = buf_id,
		lifetime_ms = 1000,

		blend = 10,

		x = 0,
		y = 0,

		color_r = 1.0,
		color_g = 0.0,
		color_b = 0.0,
	}

	return tile
end
function M.tile_emit_cell(tile)
	local start_win_id = vim.api.nvim_get_current_win()

	local function min(n, limit)
		if (n < limit) then
			n = limit
		end

		return n
	end

	-- TODO: don't emit color if the column would jet into the sign space?
	local cursor_col = min(vim.fn.wincol() - 2, 0)
	local cursor_row = vim.fn.winline() - 1
	-- local bufh = vim.api.nvim_create_buf(false, true)
	local win_id = vim.api.nvim_open_win(fg_ctx.g_buf, false, {
		relative = "win",
		width = 1,
		height = 1,
		col = cursor_col,
		row = cursor_row,
		style = "minimal"
	})
	-- vim.api.nvim_win_set_option(win_id, "winhl", "Normal: PMenu")

	local tile = M.tile_create(win_id, bufh, 0, 0)
	vim.api.nvim_win_set_option(win_id, "winblend", tile.blend)

	table.insert(fg_ctx.cells, tile)
end

local function process_frame()
	for i, v in ipairs(fg_ctx.cells) do
		v.lifetime_ms = v.lifetime_ms - update_delay_ms
		v.blend = v.blend + 1
		vim.api.nvim_win_set_option(v.win_id, "winblend", math.floor(v.blend))
	end

	for i = #fg_ctx.cells, 1, -1 do
		local cell = fg_ctx.cells[i]

		if (cell.lifetime_ms < 0) then
			vim.api.nvim_win_close(cell.win_id, true)
			-- vim.api.nvim_buf_delete(cell.buf_id, { force = true })
			table.remove(fg_ctx.cells, i)
		end
	end

	vim.defer_fn(
		function() process_frame() end, 
		update_delay_ms
	)
end

function M.on_cursor_moved()
	M.tile_emit_cell({})
end

function M.create_autocmds()
	vim.cmd("augroup Flaregun") 
	vim.cmd("autocmd!")

	vim.cmd("silent autocmd CursorMovedI * :lua require('flaregun').on_cursor_moved()")
	vim.cmd("silent autocmd CursorMoved * :lua require('flaregun').on_cursor_moved()")

	vim.cmd("augroup END")
end

function M.clear_autocmds()
	vim.cmd("augroup Flaregun")
	vim.cmd("autocmd!")
	vim.cmd("augroup END")

	if (fg_ctx.g_buf ~= nil) then
		vim.api.nvim_buf_delete(fg_ctx.g_buf, { force = true })
	end

end

function M.setup()
	M.create_autocmds()
	fg_ctx.g_buf = vim.api.nvim_create_buf(false, true)

	process_frame()
end

return M
