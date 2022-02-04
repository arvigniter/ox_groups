local groups do
    local data = LoadResourceFile('ox_groups', 'groups.lua')
    assert(data, ("failed to load %s/groups.lua"):format(resource))
    data, err = load(data, ('@@%s/groups.lua'):format(resource))

    if err then
        error(err, 0)
    end

    groups = data()
end

do
	local groupList = {}

	for group, data in pairs(groups) do
		local fmt = 'group.'..group

		-- This feels weird, am I just doing something really dumb when checking for ace permissions?
		if not IsPrincipalAceAllowed(fmt, fmt) then
			ExecuteCommand(('add_ace %s %s allow'):format(fmt, fmt))
		end

		groupList[group] = #data.ranks
		GlobalState[('group:%s'):format(group)] = data
	end

	GlobalState['groups'] = groupList
end

local players = {}
local ids = {}

local function provideExport(exportName, func)
	AddEventHandler(('__cfx_export_ox_groups_%s'):format(exportName), function(setCB)
		setCB(func)
	end)
end

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
		getGroups = getGroups,
		setGroup = setGroup
	}
end