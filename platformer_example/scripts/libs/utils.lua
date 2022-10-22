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

local function get_corners(platform)

    local corners = {}
    corners[1] = platform[#platform] -- TOP Right Corner
    local start_y = corners[1].y

    local p_w = 0

    for i = #platform, 1, -1 do
        if platform[i].y ~= start_y then
            corners[2] = platform[i + 1] -- TOP Left Corner
            break
        end
    end

    corners[3] = platform[1]
    p_w = corners[1].x - corners[2].x
    corners[4] = platform[p_w + 1]

    return corners
end

function utils.get_corner_positions(sizes, platform)
    local result = {}

    for i = 1, #platform do
        local tile = vmath.vector3(0, 0, 0.2)

        tile.x = platform[i].x * sizes.w
        tile.y = platform[i].y * sizes.h

        if i == 2 or i == 3 then
            tile.x = tile.x - sizes.w
        end

        if i == 3 or i == 4 then
            tile.y = tile.y - sizes.h
        end
        table.insert(result, tile)
    end
    return result
end

function utils.get_target_tiles(tilemap_url, tilemap_width, tilemap_height)

    local tiles = {}
    local target_tiles = {}
    local target_tilemap = {}
    local floating_platforms = {}
    local tileno = 0
    local target_tileno = 0

    for y = 1, tilemap_height do
        for x = 1, tilemap_width do
            -- Actual map tiles. NOT USING
            tileno = tilemap.get_tile(tilemap_url, "platforms", x, y)
            table.insert(tiles, tileno)

            -- Floating platforms 
            tileno = tilemap.get_tile(tilemap_url, "floating_platform", x, y)
            if tileno > 0 then
                local pos = {x = x, y = y, tile = tileno}
                table.insert(floating_platforms, pos)
            end

            -- Collision tiles for ray
            target_tileno = tilemap.get_tile(tilemap_url, "targets", x, y)
            table.insert(target_tilemap, target_tileno)

            -- Tile ids for collision. NOT USING
            if target_tileno > 0 then -- Skip blanks 
                -- 195 for platforms
                -- 41 for one-way platform 
                -- 197 for floating platform 
                table.insert(target_tiles, target_tileno)
            end
        end
    end

    floating_platforms = get_corners(floating_platforms)
    return tiles, target_tilemap, make_unique(target_tiles), floating_platforms

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

function utils.draw_rect(position, w, h)
  
    debugdraw.box(position.x , position.y, w, h, debugdraw.COLORS.green)
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
