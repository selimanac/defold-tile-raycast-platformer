local utils = require("platformer_example.scripts.libs.utils")

local manager = {}
manager.urls = {}
manager.platformer_tilemap = {}
manager.debug = false
manager.directions = {LEFT = vmath.vector3(-1, 0, 0), RIGHT = vmath.vector3(1, 0, 0), UP = vmath.vector3(0, 1, 0), DOWN = vmath.vector3(0, -1, 0)}

-- 195 for platforms
-- 41 for one-way platform 
manager.tile = {WALL = 195, FLOAT = 41}

manager.tile_size = {w = 16, h = 16}

function manager.add_url(id, url)
    manager.urls[id] = msg.url(url)
end

function manager.init()

    manager.add_url("platformer_tilemap", "/tilemap#platform")

    tilemap.set_visible(manager.urls.platformer_tilemap, "targets", false)

    local _, _, tilemap_width, tilemap_height = tilemap.get_bounds(manager.urls.platformer_tilemap)

    local platformer_tilemap, raycast_tilemap, raycast_target_tiles = utils.get_target_tiles(manager.urls.platformer_tilemap, tilemap_width, tilemap_height)

    raycast.init(manager.tile_size.w, manager.tile_size.h, tilemap_width, tilemap_height, raycast_tilemap, raycast_target_tiles)

    if manager.debug == false then
        go.delete("/fps")
    end

end

return manager
