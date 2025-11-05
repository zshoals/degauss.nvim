local M = {}


M.modules = {}


function M.init()
	--Do nothing
end

function M.loaded(script_name)
	local module = M.modules[script_name]

	if (module) then
		return module
	end

	return nil
end

function M.require(script_name)
	local module = M.modules[script_name]

	if (module) then
		return module
	end

	M.modules[script_name] = require(script_name)
	return M.modules[script_name]
end

function M.unload_all()
	for k, v in pairs(M.modules) do
		package.loaded[k] = nil
		M.modules[k] = nil
	end
end




return M
