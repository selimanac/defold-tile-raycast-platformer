local manager = {}

manager.urls = {}

manager.platformer_tilemap = {}

manager.debug = false

manager.directions = {LEFT = vmath.vector3(-1, 0, 0), RIGHT = vmath.vector3(1, 0, 0), UP = vmath.vector3(0, 1, 0), DOWN = vmath.vector3(0, -1, 0)}

local function make_unique(t)
    local hash = {}
    local res = {}
    for _, v in ipairs(t) do
        if (not hash[v]) then
            res[#res + 1] = v
            hash[v] = true
        end
    end
    return res
end


local function get_target_tiles(tilemap_width, tilemap_height)
    local tiles = {}
    local target_tiles = {}
    local target_tilemap = {}
    local tileno = 0
    local target_tileno = 0

    for y = 1, tilemap_height do
        for x = 1, tilemap_width do
            -- Actual map tiles
            tileno = tilemap.get_tile(manager.urls.platformer_tilemap, "platforms", x, y)
            table.insert(tiles, tileno)

            -- Collision tiles for ray
            target_tileno = tilemap.get_tile(manager.urls.platformer_tilemap, "targets", x, y)
            table.insert(target_tilemap, target_tileno)

            -- Tile ids for collision
            if target_tileno > 0 then -- Skip blanks 
                -- 195 for platforms
                -- 41 for one-way platform 
                table.insert(target_tiles, target_tileno)
            end
        end
    end

    return tiles, target_tilemap, make_unique(target_tiles)
end

function manager.add_url(id, url)
    manager.urls[id] = msg.url(url)
end


function manager.init()

    manager.add_url("platformer_tilemap", "/tilemap#platform")
    pprint(manager.urls)
    tilemap.set_visible(manager.urls.platformer_tilemap, "targets", false)

    local _, _, tilemap_width, tilemap_height = tilemap.get_bounds(manager.urls.platformer_tilemap)
    local tile_width = 16
    local tile_height = 16

   local platformer_tilemap, raycast_tilemap, raycast_target_tiles = get_target_tiles(tilemap_width, tilemap_height)

    raycast.init(tile_width, tile_height, tilemap_width, tilemap_height, raycast_tilemap, raycast_target_tiles)

end

return manager
