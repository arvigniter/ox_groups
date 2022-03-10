# Yet another WIP resource
Standalone resource to handle player groups such as admin, jobs, gangs, etc.  
Further logic needs to be implemented in any framework or resource utilising these groups.  

Resource can be loaded as a module directly into a framework if desired.

## Requirements
- [oxmysql](https://github.com/overextended/oxmysql)


## Database
Example table structure for ox_core and es_extended.  
You will need to change the datatype for charid and the referenced column (characters.charid).

### ox_core
```sql
CREATE TABLE `user_groups` (
  `charid` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `rank` int(11) NOT NULL,
  UNIQUE KEY `name` (`name`,`charid`) USING BTREE,
  KEY `FK_user_groups_characters` (`charid`) USING BTREE,
  CONSTRAINT `FK_user_groups_characters` FOREIGN KEY (`charid`) REFERENCES `characters` (`charid`) ON DELETE CASCADE
) ENGINE=InnoDB;
```

### es_extended
```sql
CREATE TABLE `user_groups` (
  `charid` varchar(60) NOT NULL,
  `name` varchar(50) NOT NULL,
  `rank` int(11) NOT NULL,
  UNIQUE KEY `name` (`name`,`charid`) USING BTREE,
  KEY `FK_user_groups_characters` (`charid`) USING BTREE,
  CONSTRAINT `FK_user_groups_characters` FOREIGN KEY (`charid`) REFERENCES `users` (`identifier`) ON DELETE CASCADE
) ENGINE=InnoDB;
```


## Usage
Once character data has been loaded in your framework you should immediately load the group data as well.
```lua
---@param source number server id to identify the player
---@param charid number | string unique identifier used to reference the character in the database
---@return table<string, number> groups

local groups = exports.ox_groups:load(source, charid)
```

Once group data has been loaded for a player, there are a few different ways to get the data in the future.
```lua
---@param source number server id to identify the player
---@param group? string return the player's rank in the given group
---@return number | table<string, number>
---Leave group undefined to get a table of all groups and ranks

local groups = exports.ox_groups:get(source)
-- {police = 1}

local police = exports.ox_groups:get(source, 'police')
-- 1
```

Groups can be added or modified by using the set function.
```lua
---@param source number server id to identify the player
---@param group string name of the group to adjust
---@param rank number
---Any rank under 1 will remove the group from the player.
exports.ox_groups:set(source, 'police', 1)
```

Information such as the number of ranks in a group or the labels associated with a group or its ranks are stored in statebags.  
These states can be checked on both the server and client.
```lua
local police = GlobalState['group:police']
-- police.label: LSPD
-- police.ranks: {'Cadet', 'Officer', 'Sergeant', 'Captain', 'Commander', 'Chief'}

local groups = GlobalState.groups
-- groups.police: 6

local rank = Player(source).state.police
-- 1

local rankLabel = police.ranks[rank]
-- Cadet
```

The client should use [AddStateBagChangeHandler](AddStateBagChangeHandler) to keep track of current groups.
The server can utilise an event handler.
```lua
-- client
local groups = {}

AddStateBagChangeHandler(nil, 'player:'..serverId, function(bagName, key, value, _, _)
	if key == 'police' then
		groups[key] = value
	end
end)

-- server
AddEventHandler('ox_groups:setGroup', function(source, group, rank) end)
```
