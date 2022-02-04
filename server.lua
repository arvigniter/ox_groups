local groups do
	local data = LoadResourceFile('ox_groups', 'groups.lua')
	assert(data, ("failed to load %s/groups.lua"):format(resource))
	data, err = load(data, ('@@%s/groups.lua'):format(resource))

	if err then
		error(err, 0)
	end

	groups = data()
end

local function provideExport(exportName, func)
	AddEventHandler(('__cfx_export_ox_groups_%s'):format(exportName), function(setCB)
		setCB(func)
	end)
end

---@param name string
---@param data table
--- ```
--- data = {
--- 	label = 'Display name',
--- 	ranks = {
--- 		'Rank 1 Label', 'Rank 2 Label'
--- 	}
--- }
--- ```
local function registerGroup(name, data)
	local groupList = GlobalState.groups or {}
	local fmt = 'group.'..name

	-- This feels weird, am I just doing something really dumb when checking for ace permissions?
	if not IsPrincipalAceAllowed(fmt, fmt) then
		ExecuteCommand(('add_ace %s %s allow'):format(fmt, fmt))
	end

	groupList[name] = #data.ranks
	GlobalState[('group:%s'):format(name)] = data
	GlobalState.groups = groupList
end
provideExport('registerGroup', registerGroup)

for group, data in pairs(groups) do
	registerGroup(group, data)
end

local players = {}
local ids = {}

local function getGroups(source, dbId)
	local player = players[source]

	if player then
		return player
	end

	if not dbId then
		error(("received no identifier when loading groups for 'player.%s'"):format(source))
	end

	local data = GetResourceKvpString('groups:'..dbId)
	local playerState = Player(source).state

	data = data and msgpack.unpack(data) or {}
	players[source] = data
	ids[source] = dbId

	for group, rank in pairs(data) do
		local ace = 'group.'..group
		playerState:set(group, rank, true)

		if not IsPlayerAceAllowed(source, ace) then
			ExecuteCommand(('add_principal player.%s %s'):format(source, ace))
		end
	end

	return data
end
provideExport('getGroups', getGroups)

local function setGroup(source, group, rank)
	local player = players[source]

	if player then
		local dbId = ids[source]
		local groupData = groups[group]

		if not groupData then
			error(("attempted to set invalid group '%s' on 'player.%s'"):format(group, source))
		elseif not groupData.ranks[rank] and rank > 0 then
			error(("attempted to set invalid rank '%s' for group '%s' on 'player.%s'"):format(rank, group, source))
		end

		local playerState = Player(source).state
		local ace = 'group.'..group

		if rank < 1 then
			player[group] = nil
			ExecuteCommand(('remove_principal player.%s %s'):format(source, ace))
			rank = nil
		else
			player[group] = rank

			if not IsPlayerAceAllowed(source, ace) then
				ExecuteCommand(('add_principal player.%s %s'):format(source, ace))
			end
		end

		playerState:set(group, rank, true)
		SetResourceKvp('groups:'..dbId, msgpack.pack(player))
		TriggerEvent('ox_groups:setGroup', source, group, rank)
	else
		error(("attempted to set group on invalid playerid '%s'"):format(source))
	end
end
provideExport('setGroup', setGroup)

local function userGroups(dbId)
	local data = GetResourceKvpString('groups:'..dbId)
	data = data and msgpack.unpack(data) or {}
	local labels = {}
	local size = 0

	for group in pairs(data) do
		group = groups[group]
		if group then
			size += 1
			labels[size] = group.label
		end
	end

	return labels
end
provideExport('userGroups', userGroups)

AddEventHandler('playerDropped', function()
	local player = players[source]

	if player then
		for group in pairs(player) do
			ExecuteCommand(('remove_principal player.%s group.%s'):format(source, group))
		end

		players[source] = nil
		ids[source] = nil
	end
end)

if server then
	server.groups = {
		registerGroup = registerGroup,
		getGroups = getGroups,
		setGroup = setGroup,
        userGroups = userGroups,
	}
end
