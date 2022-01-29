local groups do
    local resource = GetCurrentResourceName()
    local data = LoadResourceFile(resource, 'groups.lua')
    assert(data, ("failed to load %s/groups.lua"):format(resource))
    data, err = load(data, ('@@%s/groups.lua'):format(resource))

    if err then
        error(err, 0)
    end

    groups = data()
end

for group, data in pairs(groups) do
    GlobalState[('group:%s'):format(group)] = data
    local fmt = 'group.'..group

    -- This feels weird, am I just doing something really dumb when checking for ace permissions?
    if not IsPrincipalAceAllowed(fmt, fmt) then
        ExecuteCommand(('add_ace %s %s allow'):format(fmt, fmt))
    end
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
exports('getGroups', getGroups)

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
            playerState:set(group, nil, true)
        else
            player[group] = rank
            playerState:set(group, rank, true)

            if not IsPlayerAceAllowed(source, ace) then
                ExecuteCommand(('add_principal player.%s %s'):format(source, ace))
            end
        end

        SetResourceKvp('groups:'..dbId, msgpack.pack(player))
    else
        error(("attempted to set group on invalid playerid '%s'"):format(source))
    end
end
exports('setGroup', setGroup)

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
