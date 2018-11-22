local handler = {}
local mt = { __index = handler }

function handler.new ()
	return setmetatable ({}, mt)
end

function handler:init ()

end

return handler
