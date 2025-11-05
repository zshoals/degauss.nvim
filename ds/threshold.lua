local threshold = {}



function threshold.create(threshold_start, threshold_end, auto_refire)
	local out = {
		current = 0,
		threshold_start = threshold_start,
		threshold_end = threshold_end,

		auto_refire = auto_refire,
	}

	out.current = out.threshold_start

	return out
end



function threshold.reset(self)
	self.current = self.threshold_start
end



function threshold.step(self, n)
	local triggered = false
	self.current = self.current + n
	if (self.current >= self.threshold_end) then
		triggered = true

		if (self.auto_refire) then
			threshold.reset(self)
		end
	end

	return triggered
end



return threshold
