local debugdraw = require "debug-draw.debug-draw"

local utils = {}

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

function utils.get_target_tiles(tilemap_url, tilemap_width, tilemap_height)

    local tiles = {}
    local target_tiles = {}
    local target_tilemap = {}
    local tileno = 0
    local target_tileno = 0

    for y = 1, tilemap_height do
        for x = 1, tilemap_width do
            -- Actual map tiles 
            tileno = tilemap.get_tile(tilemap_url, "platforms", x, y)
            table.insert(tiles, tileno)

            -- Collision tiles for ray
            target_tileno = tilemap.get_tile(tilemap_url, "targets", x, y)
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

function utils.draw_rays(rays, ray_count)

    local ray = {}
    for i = 1, ray_count do
        ray = rays[i]
        msg.post("@render:", "draw_line", {start_point = ray.from, end_point = ray.to, color = vmath.vector4(1, 0, 0, 1)})
    end
  
end

function utils.draw_hit_point(intersection)
    debugdraw.circle(intersection.x, intersection.y, 5, debugdraw.COLORS.green)
end

function utils.clamp(v, min, max)
    if v < min then
        return min
    elseif v > max then
        return max
    else
        return v
    end
end

function utils.decelerate(v, f, dt)
    local opposing = math.abs(v * f)
    if v > 0 then
        return math.floor(math.max(0, v - opposing * dt))
    elseif v < 0 then
        return math.ceil(math.min(0, v + opposing * dt))
    else
        return 0
    end
end



return utils
