local manager = require("platformer_example.scripts.libs.manager")
local fsm = require("platformer_example.scripts.libs.statemachine")
local utils = require("platformer_example.scripts.libs.utils")

local hero = {}

local ray = {}
local ray_intersection = vmath.vector3(0, 0, 0)
local ray_hit = false
local ray_tile_x = 0
local ray_tile_y = 0
local ray_array_id = 0
local ray_tile_id = 0
local ray_intersection_x = 0
local ray_intersection_y = 0
local ray_side = 0
local ground_check = {FRONT = true, BACK = true}
local wall_contact = false
local oneside_platform_contact = false
local fall_start_position = vmath.vector3()
local current_bottom_position = vmath.vector3()
local platform_top_offset = 0

local MAX_GROUND_SPEED = 120
local MAX_AIR_SPEED = 80
local MAX_FALL_SPEED = 500
local GRAVITY = -500
local JUMP_TAKEOFF_SPEED = 240

local tile_size_y = 0
local tile_size_x = 0

hero.fsm = {}
hero.move = {LEFT = hash("left"), RIGHT = hash("right"), JUMP = hash("jump")}

hero.anim = {WALK = hash("hero_run"), IDLE = hash("hero_idle"), JUMP = hash("hero_jump"), FALL = hash("hero_fall"), DIE = hash("hero_die")}

local ray_count = 7
local rays = {
    [1] = { -- back
        from = vmath.vector3(0, 0, 0),
        to = vmath.vector3(0, 0, 0),
        offset = vmath.vector3(-7, -17, 0),
        offset_from = vmath.vector3(0, 0, 0)
    },
    [2] = { -- front
        from = vmath.vector3(0, 0, 0),
        to = vmath.vector3(0, 0, 0),
        offset = vmath.vector3(7, -17, 0),
        offset_from = vmath.vector3(0, 0, 0)
    },
    [3] = { -- wall
        from = vmath.vector3(0, 0, 0),
        to = vmath.vector3(0, 0, 0),
        offset = vmath.vector3(17, -10, 0),
        offset_from = vmath.vector3(0, -10, 0)
    },
    [4] = { -- forward. since raycast returns only first tile, extra check for forwarding tile.
        from = vmath.vector3(0, 0, 0),
        to = vmath.vector3(0, 0, 0),
        offset = vmath.vector3(15, 10, 0),
        offset_from = vmath.vector3(0, 10, 0)
    },
    [5] = { -- top Center
        from = vmath.vector3(0, 0, 0),
        to = vmath.vector3(0, 0, 0),
        offset = vmath.vector3(0, 15, 0),
        offset_from = vmath.vector3(0, 0, 0)
    },
    [6] = { -- top left
        from = vmath.vector3(0, 0, 0),
        to = vmath.vector3(0, 0, 0),
        offset = vmath.vector3(7, 15, 0),
        offset_from = vmath.vector3(0, 0, 0)
    },
    [7] = { -- top right
        from = vmath.vector3(0, 0, 0),
        to = vmath.vector3(0, 0, 0),
        offset = vmath.vector3(-7, 15, 0),
        offset_from = vmath.vector3(0, 0, 0)
    }
}

local function update_rays()

    for i = 1, ray_count do
        ray = rays[i]
        local p = go.get_position(hero.url)
        ray.from.x = p.x + ray.offset_from.x
        ray.from.y = p.y + ray.offset_from.y
        ray.to.x = p.x + (ray.offset.x * hero.direction)
        ray.to.y = p.y + ray.offset.y
    end

end

local function update_onair_move()
    if (hero.fsm:is("jumping") or hero.fsm:is("falling")) and wall_contact == false then
        hero.velocity.x = MAX_AIR_SPEED * hero.direction
    end
end

local function hero_die_complete()
    go.set_position(hero.initial_position, hero.url)
    go.set(hero.sprite, "tint.w", 1)
    hero.fsm:idle()
end

local function set_direction(direction)
    hero.direction = direction
    sprite.set_hflip(hero.sprite, hero.direction == -1)
end

--------------------
--- CALLBACKS
--------------------
local function on_enter_falling(self, event, from, to, msg)
    fall_start_position = go.get_position()
    fall_start_position.y = (fall_start_position.y - hero.sprite_bound.y) + platform_top_offset
    sprite.play_flipbook(hero.sprite, hero.anim.FALL)
end

local function on_enter_jumping(self, event, from, to, msg)
    hero.velocity.y = JUMP_TAKEOFF_SPEED
    sprite.play_flipbook(hero.sprite, hero.anim.JUMP)
end

local function on_leave_jumping(self, event, from, to, msg)
    if hero.velocity.y > 0 then
        hero.velocity.y = hero.velocity.y * 0.5
    end
end

local function on_enter_standing(self, event, from, to, msg)
    hero.velocity.y = 0
    hero.velocity.x = 0
    sprite.play_flipbook(hero.sprite, hero.anim.IDLE)
end

local function on_enter_walking(self, event, from, to, msg)
    hero.velocity.y = 0
    sprite.play_flipbook(hero.sprite, hero.anim.WALK)
end

local function on_leave_dying()
    hero.reset()
end

local function on_enter_dying(self, event, from, to, msg)
    sprite.play_flipbook(hero.sprite, hero.anim.DIE)
    go.animate(hero.url, "position.y", go.PLAYBACK_ONCE_FORWARD, hero.position.y + 150, go.EASING_LINEAR, 0.5, 0.3)
    go.animate(hero.sprite, "tint.w", go.PLAYBACK_ONCE_FORWARD, 0, go.EASING_LINEAR, 0.4, 0.5, hero_die_complete)
end

--------------------
--- FSM
--------------------
local function fsm_init()

    hero.fsm = fsm.create({
        initial = "init",
        -- LuaFormatter off
            events = {    
                {name = "init", from = "*", to = "setting"},
                {name = "idle", from = {"dying", "init","walking", "falling"}, to = "standing"},
                {name = "walk", from = {"standing","falling"}, to = "walking"},
                {name = "jump", from = {"standing", "walking"}, to = "jumping"},
                {name = "fall", from = {"standing","walking","jumping"}, to = "falling"},
                {name = "die", from = "*", to = "dying"},
            },
            callbacks = {
                on_enter_standing = on_enter_standing,
                on_enter_walking = on_enter_walking,
                on_enter_jumping = on_enter_jumping,
                on_leave_jumping = on_leave_jumping,
                on_enter_falling = on_enter_falling,
                on_enter_dying = on_enter_dying,
                on_leave_dying = on_leave_dying,
            }
            -- LuaFormatter on
    })
end

local function check_collisions()
    local result, count = aabb.query_id(manager.collision_group, hero.aabb_id)
    if result then
        for i = 1, count do

            if manager.saws[result[i]] and hero.fsm:is("dying") == false then
                hero.fsm:die()
            end
            if manager.apples[result[i]] and manager.apples[result[i]].active then

                manager.apples[result[i]].active = false
                msg.post(manager.apples[result[i]].url, "que_for_delete")
            end
        end
    end
end

local function update_bottom_position()
    current_bottom_position = go.get_position()
    current_bottom_position.y = (current_bottom_position.y - hero.sprite_bound.y) 
  return current_bottom_position.y
end

local function check_ground(TYPE)

    ray_intersection.x = ray_intersection_x
    ray_intersection.y = ray_intersection_y
    tile_size_y  = manager.tile_size.h * ray_tile_y
  
    -- If falling on platform
    if ray_tile_id == manager.tile.FLOAT and hero.fsm.current == "falling" and ray_side == 1 and fall_start_position.y > tile_size_y and ground_check[TYPE] == false and update_bottom_position() >  tile_size_y  then
        oneside_platform_contact = true
        ground_check[TYPE] = true
        hero.position.y = tile_size_y + hero.sprite_bound.y

        hero.fsm:idle()
    end

    -- If on platform
    if ray_tile_id == manager.tile.FLOAT and ray_side == 1 and oneside_platform_contact == true then
        ground_check[TYPE] = true
    else
        oneside_platform_contact = false
    end

    if ray_tile_id == manager.tile.WALL and ray_side == 1 and ground_check[TYPE] == false then
        ground_check[TYPE] = true
        hero.position.y = tile_size_y + hero.sprite_bound.y
        hero.fsm:idle()
    end

    if ray_tile_id == manager.tile.WALL and ray_side == 0 and ground_check[TYPE] == false then
        hero.velocity.x = 0
    end

    -- Falling on floating platform. No more needed.
    if ray_tile_id == manager.tile.PLATFORM and hero.fsm:is("falling") and ray_side == 1 and (fall_start_position.y) > (tile_size_y) and ground_check[TYPE] == false then
        ground_check[TYPE] = true
        hero.position.y = tile_size_y + hero.sprite_bound.y
        hero.fsm:idle()
    end

    if manager.debug then
        utils.draw_hit_point(ray_intersection)
    end
end

--------------------
--- UPDATE
--------------------
function hero.update(self, dt)

    if hero.fsm:is("dying") then
        return
    end

    -- Walk
    if hero.fsm:is("walking") and wall_contact == false then
        hero.velocity.x = MAX_GROUND_SPEED * hero.direction
    end

    if ground_check.BACK == false and ground_check.FRONT == false then

        -- ON AIR Gravity
        hero.velocity.y = hero.velocity.y + GRAVITY * dt
        hero.velocity.y = utils.clamp(hero.velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED)

        -- ON AIR Move
        hero.velocity.x = utils.decelerate(hero.velocity.x, 1, dt)
        hero.velocity.x = utils.clamp(hero.velocity.x, -MAX_AIR_SPEED, MAX_AIR_SPEED)
    else
        -- ON GROUND Move
        hero.velocity.x = utils.decelerate(hero.velocity.x, 20, dt)
        hero.velocity.x = utils.clamp(hero.velocity.x, -MAX_GROUND_SPEED, MAX_GROUND_SPEED)

    end

    hero.position = hero.position + hero.velocity * dt

    update_rays()

    -- Debug lines
    if manager.debug then
        utils.draw_rays(rays, ray_count)
    end

    -- FRONT RAY 
    ray_hit, ray_tile_x, ray_tile_y, ray_array_id, ray_tile_id, ray_intersection_x, ray_intersection_y, ray_side = raycast.cast(rays[2].from, rays[2].to)
    if ray_hit then
        check_ground("FRONT")
    else
        ground_check.FRONT = false
    end

    -- BACK RAY 
    ray_hit, ray_tile_x, ray_tile_y, ray_array_id, ray_tile_id, ray_intersection_x, ray_intersection_y, ray_side = raycast.cast(rays[1].from, rays[1].to)
    if ray_hit then
        check_ground("BACK")
    else
        ground_check.BACK = false
    end

    --------------------
    -- Fall from jumping
    if hero.fsm:is("jumping") and hero.velocity.y < 0 then
        hero.fsm:fall()
    end

    -- Fall from edge
    if ground_check.BACK == false and ground_check.FRONT == false and hero.fsm:is("jumping") == false then
        hero.fsm:fall()
    end
    --------------------

    -- WALL RAY 
    ray_hit, ray_tile_x, ray_tile_y, ray_array_id, ray_tile_id, ray_intersection_x, ray_intersection_y, ray_side = raycast.cast(rays[3].from, rays[3].to)
    if ray_hit then

        ray_intersection.x = ray_intersection_x
        ray_intersection.y = ray_intersection_y

        if ray_tile_id == manager.tile.WALL then

            if hero.fsm.current == "falling" then
                hero.velocity.x = (-20 * hero.direction)
            end

            if hero.fsm.current == "walking" then
                hero.velocity.x = 0
            end

            wall_contact = true
        end

        if manager.debug then
            utils.draw_hit_point(ray_intersection)
        end
    else
        wall_contact = false
    end

    -- FORWARD RAY for one way platforms for safety.
    ray_hit, ray_tile_x, ray_tile_y, ray_array_id, ray_tile_id, ray_intersection_x, ray_intersection_y, ray_side = raycast.cast(rays[4].from, rays[4].to)
    if ray_hit then
        ray_intersection.x = ray_intersection_x
        ray_intersection.y = ray_intersection_y

        if ray_hit then

            if ray_tile_id == manager.tile.WALL then
                if hero.fsm.current == "falling" or hero.fsm.current == "jumping" then
                    hero.velocity.x = (-20 * hero.direction)
                else
                    --  hero.position.x = (manager.tile_size.w * (ray_tile_x - (hero.direction == -1 and 0 or 1))) - hero.sprite_bound.x * hero.direction
                    hero.velocity.x = 0
                end

                wall_contact = true
            end
        end

        if manager.debug then
            utils.draw_hit_point(ray_intersection)
        end
    end

    -- Top Ray
    ray_hit, ray_tile_x, ray_tile_y, ray_array_id, ray_tile_id, ray_intersection_x, ray_intersection_y, ray_side = raycast.cast(rays[5].from, rays[5].to)
    if ray_hit then
        ray_intersection.x = ray_intersection_x
        ray_intersection.y = ray_intersection_y

        if ray_hit then

            if ray_tile_id == manager.tile.WALL and ray_side == 1 then
                hero.velocity.y = -100
            end
        end

        if manager.debug then
            utils.draw_hit_point(ray_intersection)
        end
    end

    -- Top Left
    ray_hit, ray_tile_x, ray_tile_y, ray_array_id, ray_tile_id, ray_intersection_x, ray_intersection_y, ray_side = raycast.cast(rays[6].from, rays[6].to)
    if ray_hit then
        ray_intersection.x = ray_intersection_x
        ray_intersection.y = ray_intersection_y

        if ray_hit then

            if ray_tile_id == manager.tile.WALL and ray_side == 1 then
                hero.velocity.y = -100
                hero.velocity.x = (-20 * hero.direction)
            end
        end

        if manager.debug then
            utils.draw_hit_point(ray_intersection)
        end
    end

    -- Top Left
    ray_hit, ray_tile_x, ray_tile_y, ray_array_id, ray_tile_id, ray_intersection_x, ray_intersection_y, ray_side = raycast.cast(rays[7].from, rays[7].to)
    if ray_hit then
        ray_intersection.x = ray_intersection_x
        ray_intersection.y = ray_intersection_y

        if ray_hit then

            if ray_tile_id == manager.tile.WALL and ray_side == 1 then
                hero.velocity.y = -100
                hero.velocity.x = (-20 * hero.direction)
            end
        end

        if manager.debug then
            utils.draw_hit_point(ray_intersection)
        end
    end

    -- Set the new possition
    go.set_position(hero.position)

    -- Check collisions
    check_collisions()

    if manager.debug then
        utils.draw_rect(hero.position, hero.size.w, hero.size.h)
    end

end

--------------------
--- INPUT
--------------------
function hero.input(self, action_id, action)

    if action_id == hero.move.LEFT then
        set_direction(-1)
        update_onair_move()

        if hero.fsm:is("falling") == false then
            hero.fsm:walk()
        end

        if action.released and hero.fsm:is("walking") then
            hero.fsm:idle()
        end

    elseif action_id == hero.move.RIGHT then
        set_direction(1)
        update_onair_move()

        if hero.fsm:is("falling") == false then
            hero.fsm:walk()
        end

        if action.released and hero.fsm:is("walking") then
            hero.fsm:idle()
        end

    elseif action_id == hero.move.JUMP then

        if action.pressed then
            hero.fsm:jump()
        elseif action.released then

            if hero.fsm.current == "jumping" then

                hero.fsm:fall()
            end
        end

    end

end

function hero.reset()
    hero.direction = 1
    set_direction(hero.direction)
    hero.velocity = vmath.vector3(0, 0, 0)
    hero.position = go.get_position(hero.url)
end

function hero.init()

    hero.url = msg.url(".")
    hero.sprite = msg.url("#hero_sprite")
    hero.position = go.get_position(hero.url)
    hero.initial_position = go.get_position(hero.url)
    hero.sprite_size = go.get(hero.sprite, "size")
    hero.sprite_bound = go.get(hero.sprite, "size") / 2
    hero.direction = 1
    hero.velocity = vmath.vector3(0, 0, 0)

    hero.size = {w = 18, h = 26}

    fsm_init()
    update_rays()
    hero.fsm:idle()

    manager.add_url("hero", hero.url)

end

return hero
