fx_version 'cerulean'
game 'gta5'

author 'Wari'
description 'Made by: dyyykmetrpadesat'
version '1.0.0' -- First release

data_file 'DLC_ITYP_REQUEST' 'stream/alca_anim_eat.ytyp'

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    'config.lua'
}

client_scripts {
    'client/cl.lua'
}

server_scripts {
    'server/sv.lua'
}

dependency '/assetpacks'
dependency '/assetpacks'
