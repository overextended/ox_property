--[[ FX Information ]]--
fx_version   'cerulean'
use_experimental_fxv2_oal 'yes'
lua54        'yes'
game         'gta5'

--[[ Resource Information ]]--
name         'ox_property'
version      '0.10.0'
description  'Property'
license      'GPL-3.0-or-later'
author       'overextended'
repository   'https://github.com/overextended/ox_property'

--[[ Manifest ]]--
dependencies {
    '/server:5104',
    '/onesync',
}

shared_scripts {
    '@ox_lib/init.lua',
	'shared.lua',
}

client_scripts {
    '@ox_core/imports/client.lua',
    'client/main.lua',
    'client/management.lua',
    'client/parking.lua',
    'client/wardrobe.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@ox_core/imports/server.lua',
    'server/main.lua',
    'server/management.lua',
    'server/parking.lua',
    'server/wardrobe.lua',
}

files {
    '/data/**'
}

ox_property_data '/data/3671_whispymound_drive.lua'
ox_property_data '/data/7611_goma_street.lua'
ox_property_data '/data/casa_philips.lua'
ox_property_data '/data/pillbox_hill_parking.lua'
ox_property_data '/data/the_clinton_residence.lua'
ox_property_data '/data/the_crest_residence.lua'
ox_property_data '/data/the_de_santa_residence.lua'
