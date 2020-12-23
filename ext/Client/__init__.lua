
local explosionEntityData = nil

local function getExplosionEntityData()
	if explosionEntityData ~= nil then
		return explosionEntityData
	end

	local original = ResourceManager:SearchForInstanceByGuid(Guid('D41B0855-6874-4650-8064-DC9F7ED76B0E'))	--5FE6E2AD-072E-4722-984A-5C52BC66D4C1

	if original == nil then
		print('Could not find explosion template')
		return nil
	end

	explosionEntityData = VeniceExplosionEntityData(original:Clone())

	return explosionEntityData
end

NetEvents:Subscribe('Bot:Killed', function(position)

	local data = getExplosionEntityData()

	if data == nil then
		print('Could not get explosion data')
		return
	end

	-- Create the entity at the provided position.
	local transform = LinearTransform()
	transform.trans = position

	local entity = EntityManager:CreateEntity(data, transform)

	if entity == nil then
		print('Could not create entity.')
		return
	end

	entity = ExplosionEntity(entity)
	--entity:Init(Realm.Realm_ClientAndServer, true)
	entity:Detonate(transform, Vec3(0, 1, 0), 1.0, nil)
end)

Events:Subscribe('Level:LoadResources', function()
	explosionEntityData = nil
end)
