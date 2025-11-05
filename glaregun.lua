
-- name: Degauss

-- TODO: Virtualize the xy grid so that cursor movements
-- 		across windows is uniform with one simple way
-- 		to index positions
--
-- TODO: Track down performance issue if left idle for long periods
-- 		of time...garbage collection from old windows? Pool them?
--
-- 		It's possible that creating tons of windows, even if they are deleted,
-- 		is problematic for neovim
--
-- 		Maybe defer_fn causes problems? Use vim.uv.loop or whatever instead?
--
-- 		Maybe losing focus for long periods causes problems?
--
-- 		Make another idle timer for "hard idle", user has been away for
-- 		multiple minutes and we want to stop processing as frequently and
-- 		stop effects completely -- secondary update_delay_ms for hard idle
--
-- 		I assume you're using block cursor for normal mode, and bar for 
-- 		insert mode. However, there are other cursor types, like underline;
-- 		we probably want to support most of them. Underline/empty box should
-- 		emanate trails too in their center location, probably.
--
--
-- IDEAS: Idle animation ideas:
-- 			Dark Portal (red eyes in a swirling black void)
-- 			Rift (blue energy rift, another portal)
-- 			Dosage (high radiation visual anomalies)
-- 			Degauss (sweep screen with blue pulses)
-- 			Fireworks (self-explanatory)
-- 			Auras (circular rotating rings, or pulsing areas of effect)
-- 			Point pulses (slow expanding aoes)
-- 			Burning fuse (takes a long time?
-- 			Snake?
-- 			DVD bouncer (With "Degauss" as the text)
local M = {}

local fg_ctx = {
	should_exit = false, 

	g_buf = {},
	cells = {},

	x = 1,
	y = 1,
	x_prev = 1,
	y_prev = 1,

	--This determines how far away the initial 
	--trail is from the cursor
	chaser_offset = 1,

	update_delay_ms = 8,

	idle_timer = 0,
	idle_threshold = 500,

	pulse = {
		process = false,
		recur_frequency = 1500,
		recur_timer = 0,
		max_dist = 12,
		cur_dist = 0,
		spread_refire_threshold = 8,
		spread_refire_current_time = 0,
	},
}

local function cursor_is_idle()
	return (fg_ctx.idle_timer  > fg_ctx.idle_threshold)
end

local pulse_clear = function()
	fg_ctx.pulse.cur_dist = 0
	fg_ctx.pulse.spread_refire_current_time = 0
	fg_ctx.pulse.recur_timer = 0
end

local pulse_step_cell = function()
	fg_ctx.pulse.cur_dist = fg_ctx.pulse.cur_dist + 1
end

local pulse_reset_cell = function()
	fg_ctx.pulse.cur_dist = 0
end

local function pulse_reset_spread_timer()
	fg_ctx.pulse.spread_refire_current_time = 0
end

local function pulse_reset_recur_timer()
	fg_ctx.pulse.recur_timer = 0
end

local function pulse_advance_time(amount)
	fg_ctx.pulse.spread_refire_current_time = fg_ctx.pulse.spread_refire_current_time + amount
	fg_ctx.pulse.recur_timer = fg_ctx.pulse.recur_timer + amount
end

local function pulse_try(x, y, update_time_ms)
	local p = fg_ctx.pulse

	-- TODO: This doesn't work for some reason when "not" is applied to the function
	-- it should just stop you from activating this section until idle, 
	-- but instead it hard blocks it. Why?
	if (not cursor_is_idle()) then
		pulse_clear()
		return
	end

	pulse_advance_time(update_time_ms)

	if (p.recur_timer > p.recur_frequency) then
		--fire a pulse
		p.process = true
		pulse_reset_recur_timer()
	end

	if (p.process) then
		if (p.cur_dist < p.max_dist) then
			if (p.spread_refire_current_time > p.spread_refire_threshold) then
				pulse_reset_spread_timer()
				pulse_step_cell()


				local blend_start = 0
				M.cell_create(
					x - p.cur_dist + 1,
					y,
					1,
					0,
					0,
					0,
					1000,
					blend_start,
					100
				)

				M.cell_create(
					x + p.cur_dist + 1,
					y,
					1,
					0,
					0,
					0,
					1000,
					blend_start,
					100
				)
			end
		else
			p.process = false
			pulse_reset_cell()
			pulse_reset_spread_timer()
		end
	end

end

local min = function(n, limit)
	if (n < limit) then
		n = limit
	end

	return n
end

local is_normal_mode = function(mode)
	return (mode == "n")
end

local is_insert_mode = function(mode)
	return (mode == "i")
end

local calc_chaser_type = function()
	local mode = vim.api.nvim_get_mode()["mode"]

	if (is_normal_mode(mode)) then
		fg_ctx.chaser_offset = 1
	elseif (is_insert_mode(mode)) then
		fg_ctx.chaser_offset = 1
	else
		fg_ctx.chaser_offset = 0
	end
end

local get_cursor_position = function()
	local x = vim.fn.wincol() - 1
	local y = vim.fn.winline() - 1

	return x, y
end

local update_cursor_position = function()
	fg_ctx.x, fg_ctx.y = get_cursor_position()
end

local store_current_cursor_position = function()
	fg_ctx.x_prev = fg_ctx.x
	fg_ctx.y_prev = fg_ctx.y
end

local sign_of = function(n)
	local out = 1
	if (n < 0) then
		out = -1
	end

	return out
end

local get_cursor_movement_signs = function()
	local x_dir = fg_ctx.x - fg_ctx.x_prev
	local y_dir = fg_ctx.y - fg_ctx.y_prev

	return sign_of(x_dir), sign_of(y_dir)
end

local did_cursor_move_xy = function()
	return not ( (fg_ctx.x == fg_ctx.x_prev) and (fg_ctx.y == fg_ctx.y_prev) )
end

local did_cursor_move_y_only = function()
	return ( (fg_ctx.x == fg_ctx.x_prev) and (fg_ctx.y ~= fg_ctx.y_prev) )
end

local function cell_hide(cell)
	local config = vim.api.nvim_win_get_config(cell.win_id)
	config.hide = true
	vim.api.nvim_win_set_config(cell.win_id, config)
end

local function cell_show(cell)
	local config = vim.api.nvim_win_get_config(cell.win_id)
	config.hide = false
	vim.api.nvim_win_set_config(cell.win_id, config)
end

local function camera_extents(win)
	local cam = vim.fn.wingetinfo(win)

	local extents = {
		up = cam.topline,
		down = cam.botline,
		left = cam.leftcol,
		right = cam.width,
	}

	return extents
end

local function cell_visible_in_window(cell)
	local cam = camera_extents(cell.win_id)
end

M.cell_create = function(x, y, dir, r, g, b, lifetime, blend_start, blend_end)
	local cell = {
		win_id = {},

		lifetime_ms = lifetime,

		blend = blend_start,
		blend_end = 100,

		x = x,
		y = y,

		r = r,
		g = g,
		b = b,
	}

	cell.win_id = vim.api.nvim_open_win(fg_ctx.g_buf, false, {
		relative = "win",
		width = 1,
		height = 1,
		--Adjust win spawn positions for vim's weird 1 indexing + trail offsets
		col = min(x - (fg_ctx.chaser_offset * dir), 0),
		row = min(y, 0),
		style = "minimal",
		focusable = false
	})

	vim.api.nvim_win_set_option(cell.win_id, "winblend", cell.blend)

	table.insert(fg_ctx.cells, cell)
end

M.cell_create_default = function(x, y, dir)
	return M.cell_create(x, y, dir, "ff", "ff", "ff", 1000, 10, 100)
end

local function process_frame()
	update_cursor_position()

	local did_move = did_cursor_move_xy()
	if (did_move) then
		fg_ctx.idle_timer = 0
		calc_chaser_type()

		local xsign, ysign = get_cursor_movement_signs()
		--hack
		--don't put this here, fixup calc chaser types
		local insert_adjust = 0
		if ( (xsign < 0) and (is_insert_mode(vim.api.nvim_get_mode()["mode"])) ) then
			insert_adjust = -1
		end
		M.cell_create_default(fg_ctx.x + insert_adjust, fg_ctx.y, xsign)
	else
		-- idling cursor
		fg_ctx.idle_timer = fg_ctx.idle_timer + fg_ctx.update_delay_ms
		pulse_try(fg_ctx.x, fg_ctx.y, fg_ctx.update_delay_ms)

	end

	-- Age cell lifetime
	for i, cell in ipairs(fg_ctx.cells) do
		cell.lifetime_ms = cell.lifetime_ms - fg_ctx.update_delay_ms
		cell.blend = cell.blend + 0.75
		vim.api.nvim_win_set_option(cell.win_id, "winblend", math.floor(cell.blend))
	end

	-- Clean up lifetime-expired entries
	for i = #fg_ctx.cells, 1, -1 do
		local cell = fg_ctx.cells[i]

		if (cell.lifetime_ms < 0) then
			vim.api.nvim_win_close(cell.win_id, true)
			table.remove(fg_ctx.cells, i)
		end
	end

	store_current_cursor_position()


	if (fg_ctx.should_exit) then
		for k, cell in pairs(fg_ctx.cells) do
			vim.api.nvim_win_close(cell.win_id, true)
		end

		vim.api.nvim_buf_delete(fg_ctx.g_buf, { force = true })
		return
	end

	vim.defer_fn(
		function() process_frame() end,
		fg_ctx.update_delay_ms
	)
end

function M.shutdown()
	fg_ctx.should_exit = true
end

M.setup = function()
	fg_ctx.should_exit = false

	update_cursor_position()
	store_current_cursor_position()
	calc_chaser_type()

	fg_ctx.g_buf = vim.api.nvim_create_buf(false, true)
	
	process_frame()
end


return M



