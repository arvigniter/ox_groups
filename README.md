## Yet another WIP resource

Standalone "group manager" resource to simplify permissions across different frameworks with data persistence (KVP) and states (GlobalState and Player Statebags).  
Further logic needs to be implemented in any framework or resource utilising these groups, i.e.

```lua
-- server
player.groups = exports.groups:loadGroups(source, dbId)
```
dbId is any sort of unique identifier; this might be a standard rockstar license, CitizenId, or some incrementing value.  
This works with [cfx-server-data/player-data](https://github.com/citizenfx/cfx-server-data/blob/master/resources/[gameplay]/player-data/server.lua), assuming it is being utilised; although it wouldn't support multicharacter systems.
```lua
local dbId = Player(source).state['cfx.re/playerData@id']
local groups = exports.groups:loadGroups(source, dbId)
```
```lua
-- client
local playerState = LocalPlayer.state

local police = GlobalState['group:police']
print(police.label, police.ranks[playerState.police])

local ox = GlobalState['group:ox']
print(ox.label, ox.ranks[playerState.ox])
```

To adjust a players groups or ranks, you can utilise setGroup. Any rank under 1 will remove the group.
```lua
exports.groups:setGroup(source, dbId, 'police', 2)
```
