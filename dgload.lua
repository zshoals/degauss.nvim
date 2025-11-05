local M = {}

local ctx = { }
local first_load = true
local hotreload = require("util.hotreloader")

function M.try_shutdown()
	local degauss_module = hotreload.loaded("degauss")
	if (degauss_module) then
		degauss_module.shutdown(ctx)
	end

	degauss_module = nil

	hotreload.unload_all()
end

function M.try_load()
	if (first_load) then
		hotreload.init()

		first_load = false
	end

	M.try_shutdown()

	--//NOTE(zpc 11-05-2025):> Because Degauss uses a vim.defer_fn,
	--  trying to reload the Degauss script can fail if try_load() is called
	--  twice in a row as the defer_fn in Degauss is still active, stopping
	--  the Degauss unload. Force a wait here before triggering the unload
	--  so that the shutdown routine in Degauss has time to execute and also
	--  exit the defer_fn.
	vim.defer_fn( 
		function()
			local degauss_module = hotreload.require("degauss")
			if (degauss_module) then
				degauss_module.setup(ctx, {})
			else
				assert(false, "Degauss failed to load for some reason")
			end
		end,
		16
	)
end


return M
