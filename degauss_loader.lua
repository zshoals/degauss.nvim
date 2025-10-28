local M = {}

function M.try_load()
	if (package.loaded["glaregun"]) then
		require("glaregun").shutdown()
	end

	package.loaded["glaregun"] = nil

	require("glaregun").setup()
end

function M.shutdown()
	require("glaregun").shutdown()
	package.loaded["glaregun"] = nil
end

return M
