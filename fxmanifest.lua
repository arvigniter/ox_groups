--[[ FX Information ]]--
fx_version   'cerulean'
use_fxv2_oal 'yes'
lua54        'yes'
game         'gta5'

--[[ Resource Information ]]--
name         'ox_groups'
author       'Overextended'
version      '0.0.2'
repository   'https://github.com/overextended/ox_groups'
description  'Standalone group management'

--[[ Manifest ]]--
server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'@ox_lib/init.lua',
    'server/groups.lua'
}
