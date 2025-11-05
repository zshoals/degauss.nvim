local Degauss = {}




local hotreload = require("util.hotreloader")
local threshold = hotreload.require("ds/threshold")



function Degauss.ctx_create_defaults(ctx)
	ctx.time = {
		previous = 0,
		current = 0,
		dt = 0,
	}
	ctx.loop = {
		accumulator = {},
		update_period_ms = 8,

		should_exit = false,
	}
	ctx.state = {
		print_state = false,
	}

	ctx.loop.accumulator = threshold.create(0, 2000, true)

	local now = vim.fn.reltimefloat(vim.fn.reltime())
	ctx.time.current = now
	ctx.time.previous = now
end



function Degauss.release_resources(ctx)
	-- Close all windows/extmarks/hl groups here
end



function Degauss.update_dt(ctx)
	local now = vim.fn.reltimefloat(vim.fn.reltime())

	ctx.time.previous = ctx.time.current
	ctx.time.current = now
	ctx.time.dt = ctx.time.current - ctx.time.previous
	ctx.time.dt = ctx.time.dt * 1000
end



function Degauss.initialize_dt(ctx)
	local now = vim.fn.reltimefloat(vim.fn.reltime())
	ctx.time.current = now
	ctx.time.previous = now
end



function Degauss.step_and_test_accumulator(ctx)
	--vim.print(ctx.loop.accumulator.current)
	return threshold.step(ctx.loop.accumulator, ctx.time.dt)
end



function Degauss.shutdown(ctx)
	ctx.loop.should_exit = true
end



function Degauss.frame_step(ctx)
	if (ctx.loop.should_exit) then
		Degauss.release_resources(ctx)
		return
	end

	Degauss.update_dt(ctx)

	if (Degauss.step_and_test_accumulator(ctx)) then
		-- Process the frame
		if (ctx.print_state) then
			vim.print("yaboy")
		else
			vim.print("FUCK U")
		end

		ctx.print_state = not ctx.print_state
	end

	vim.defer_fn(
		function() Degauss.frame_step(ctx) end,
		ctx.loop.update_period_ms
	)
end



function Degauss.setup(ctx, opts)
	Degauss.ctx_create_defaults(ctx)
	Degauss.initialize_dt(ctx)

	Degauss.frame_step(ctx)
end





return Degauss
