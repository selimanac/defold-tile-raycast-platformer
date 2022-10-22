local utils = require("platformer_example.scripts.libs.utils")

local manager = {}
manager.urls = {}
manager.platformer_tilemap = {}
manager.floating_platforms = {}
manager.debug = false
manager.directions = {LEFT = vmath.vector3(-1, 0, 0), RIGHT = vmath.vector3(1, 0, 0), UP = vmath.vector3(0, 1, 0), DOWN = vmath.vector3(0, -1, 0)}
manager.saws = {}
manager.apples = {}
manager.collision_group = -1

-- 195 for ground and walls
-- 41 for one-way platform 
-- 197 for floating platform 
manager.tile = {WALL = 195, FLOAT = 41, PLATFORM = 197}
manager.tile_size = {w = 16, h = 16}

function manager.add_url(id, url)
    manager.urls[id] = msg.url(url)
end

function manager.add_saw(aabb_id, url)
    table.insert(manager.saws, aabb_id, url)
end

function manager.add_apple(aabb_id, url, position)
    local v = {
        url = url,
        active = true
    }
    table.insert(manager.apples, aabb_id, v)
end
function manager.init()

    manager.collision_group = aabb.new_group()

    manager.add_url("platformer_tilemap", "/tilemap#platform")

    tilemap.set_visible(manager.urls.platformer_tilemap, "targets", false)

    local _, _, tilemap_width, tilemap_height = tilemap.get_bounds(manager.urls.platformer_tilemap)
    local platformer_tilemap, raycast_tilemap, raycast_target_tiles, floating_platforms = utils.get_target_tiles(manager.urls.platformer_tilemap, tilemap_width, tilemap_height)

    manager.floating_platforms = utils.get_corner_positions(manager.tile_size, floating_platforms)

    -- SEND INIT MESSAGES
    msg.post(manager.urls.saw, "start_anim")
    msg.post(manager.urls.hero, "set_aabb")
    for i = 1, 7 do
        msg.post("/apple"..i, "set_aabb")
    end

    -- Init Tile raycast
    raycast.init(manager.tile_size.w, manager.tile_size.h, tilemap_width, tilemap_height, raycast_tilemap, raycast_target_tiles)

    if manager.debug == false then
        go.delete("/fps")
    end

end

return manager
