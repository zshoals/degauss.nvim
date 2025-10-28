

local M = {}

local storage = {
	ppbuf = vim.api.nvim_create_buf(false, true),
	windows = {},
	makedel = false,
	continue = true,
}

function M.spam()
	for x=1, 40 do
		for y=1, 12 do
			local xoff = 100
			local yoff = 10
			local win_id = vim.api.nvim_open_win(storage.ppbuf, false, {
				relative = "win",
				width = 1,
				height = 1,
				col = x + xoff,
				row = y + yoff,
				style = "minimal",
				focusable = false,
			})

			vim.api.nvim_win_set_option(win_id, "winblend", 50)

			table.insert(storage.windows, win_id)
		end
	end
end

function M.clear()
	for i=#storage.windows, 1, -1 do
		local window = table.remove(storage.windows)
		vim.api.nvim_win_close(window, true)
		window = nil
	end
end

local function process()
	local x = 100
	local y = 20
	if (not storage.makedel) then
		local win_id = vim.api.nvim_open_win(storage.ppbuf, false, {
			relative = "win",
			width = 1,
			height = 1,
			col = x,
			row = y,
			style = "minimal",
			focusable = false,
		})

		vim.api.nvim_win_set_option(win_id, "winblend", 0)

		table.insert(storage.windows, win_id)
	else
		local window = table.remove(storage.windows)
		vim.api.nvim_win_close(window, true)
		window = nil
	end

	storage.makedel = not storage.makedel

	if (storage.continue) then
		vim.defer_fn(
			function() process() end,
			8
		)
	else
		return
	end
end

function M.stop()
	storage.continue = false
end

function M.setup()
	storage.continue = true
	process()
end

return M
