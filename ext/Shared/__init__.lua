Events:Subscribe('Partition:Loaded', function(partition)
	for _, instance in pairs(partition.instances) do
		if instance:Is('GunSwayData') then
			instance = GunSwayData(instance)
			-- Make it writable so we can modify its fields.
			instance:MakeWritable()

			instance.deviationScaleFactorNoZoom = 0.5
			instance.gameplayDeviationScaleFactorNoZoom = 0.5
		end
	end
end)