local base = _G

module('Factory')

function setBaseClass(class, baseClass)
	base.setmetatable(class, baseClass.mtab)
end

create = function(class, ...)
  --base.print('Factory:create()', class)
	local w = {}
	setBaseClass(w, class)
	w:construct(base.unpack(arg))
	return w
end

