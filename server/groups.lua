local function provideExport(exportName, func)
	AddEventHandler(('__cfx_export_ox_groups_%s'):format(exportName), function(setCB)
		setCB(func)
	end)
end

local groups = {
	---```lua
	---groups.list[groupName] = {
	---	label: string,
	---	ranks: array<string>
	---}
	---```
	list = {},
}

local players = {}

local groupData = setmetatable({}, {
	__index = function(self, index)
		self[index] = {}
		return self[index]
	end
})

---@param name string
---@param data table
--- ```lua
--- exports.ox_groups:new('police', {
--- 	label = 'LSPD',
--- 	ranks = 'Cadet', 'Officer', 'Sergeant', 'Captain', 'Commander', 'Chief'
--- })
--- ```
function groups.new(name, data)
	local groupState = GlobalState.groups or {}
	local ranks = #data.ranks
	local parent = ('group.%s'):format(name)

	if not IsPrincipalAceAllowed(parent, parent) then
		lib.addAce(parent, parent)

		for i = 1, ranks do
			local child = ('group.%s:%s'):format(name, i)
			lib.addAce(child, child)
			lib.addPrincipal(child, parent)
			parent = child
		end
	end

	groups.list[name] = data
	groupState[name] = ranks
	GlobalState[('group:%s'):format(name)] = data
	GlobalState.groups = groupState
end
provideExport('new', groups.new)

do
	local group = LoadResourceFile('ox_groups', 'server/data.lua')
	assert(group, 'failed to load ox_groups/server/data.lua')
	group, err = load(group, '@@ox_groups/server/data.lua')

	if err then
		error(err, 0)
	end

	for name, data in pairs(group()) do
		groups.new(name, data)
	end
end

local Query = {
	SELECT_GROUPS = 'SELECT name, rank FROM user_groups WHERE charid = ?',
	UPDATE_GROUP = 'INSERT INTO user_groups (charid, name, rank) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE rank = VALUES(rank)',
	DELETE_GROUP = 'DELETE FROM user_groups WHERE charid = ? AND name = ?'
}

---@param source number server id to identify the player
---@param charid number | string unique identifier used to reference the character in the database
---@return table<string, number> groups
function groups.load(source, charid)
	if source then
		local currentId = players[source]

		if currentId ~= charid then
			if currentId then
				print(currentId, currentId and groupData[currentId] and next(groupData[currentId]))
				if next(groupData[currentId]) then
					for name, rank in pairs(groupData[currentId]) do
						print('remove', rank, rank, 'from', currentId)
						lib.removePrincipal(source, ('group.%s:%s'):format(name, rank))
					end
				end
			end

			players[source] = charid
		end
	end

	if next(groupData[charid]) then
		for name, rank in pairs(groupData[charid]) do
			groups.set(source, name, rank)
		end

		return groupData[charid]
	end

	for _, group in pairs(MySQL.query.await(Query.SELECT_GROUPS, { charid })) do
		groupData[charid][group.name] = group.rank
	end

	return groupData[charid]
end
provideExport('load', groups.load)

---@param source number server id to identify the player
---@param group? string return the player's rank in the given group
---@return number | table<string, number>
---Leave group undefined to get a table of all groups and ranks
function groups.get(source, group)
	if source then
		local charid = players[source]

		if group then
			return groupData[charid][group]
		end

		return groupData[charid]
	end

	return groups.list
end
provideExport('get', groups.get)

---@param source number server id to identify the player
---@param group string name of the group to adjust
---@param rank number
---Any rank under 1 will remove the group from the player.
function groups.set(source, group, rank)
	if source then
		local charid = players[source]
		local data = groups.list[group]

		if not data then
			error(("attempted to set invalid group '%s' on 'player.%s'"):format(group, source))
		elseif not data.ranks[rank] and rank > 0 then
			error(("attempted to set invalid rank '%s' for group '%s' on 'player.%s'"):format(rank, group, source))
		end

		local currentRank = groupData[charid][group]

		if currentRank then
			lib.removePrincipal(source, ('group.%s:%s'):format(group, currentRank))
		end

		if rank < 1 then
			if not groupData[charid][group] then return end
			rank = nil
			MySQL.prepare(Query.DELETE_GROUP, { charid, group })
		else
			MySQL.prepare(Query.UPDATE_GROUP, { charid, group, rank })
			lib.addPrincipal(source, ('group.%s:%s'):format(group, rank))
		end

		Player(source).state:set(group, rank, true)
		TriggerEvent('ox_groups:setGroup', source, group, rank)

		groupData[charid][group] = rank
	end
end
provideExport('set', groups.set)

if GetCurrentResourceName() == 'ox_core' then
	server.groups = groups
end
