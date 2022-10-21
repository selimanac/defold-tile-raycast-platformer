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

local MAX_GROUND_SPEED = 120
local MAX_AIR_SPEED = 80
local MAX_FALL_SPEED = 500
local GRAVITY = -500
local JUMP_TAKEOFF_SPEED = 240

hero.fsm = {}
hero.move = {LEFT = hash("left"), RIGHT = hash("right"), JUMP = hash("jump")}

hero.anim = {WALK = hash("hero_run"), IDLE = hash("hero_idle"), JUMP = hash("hero_jump"), FALL = hash("hero_fall")}

local ray_count = 4
local rays = {
    [1] = { -- back
        from = vmath.vector3(0, 0, 0),
        to = vmath.vector3(0, 0, 0),
        offset = vmath.vector3(-7, -17, 0),
        offset_from =  vmath.vector3(0, 0, 0)
    },
    [2] = { -- front
        from = vmath.vector3(0, 0, 0),
        to = vmath.vector3(0, 0, 0),
        offset = vmath.vector3(7, -17, 0),
        offset_from =  vmath.vector3(0, 0, 0)
    },
    [3] = { -- wall
        from = vmath.vector3(0, 0, 0),
        to = vmath.vector3(0, 0, 0),
        offset = vmath.vector3(17, -8, 0),
        offset_from =  vmath.vector3(0, 0, 0)
    },
    [4] = { -- forward
        from = vmath.vector3(0, 0, 0),
        to = vmath.vector3(0, 0, 0),
        offset = vmath.vector3(17, 10, 0),
        offset_from =  vmath.vector3(0,10, 0)
    }
}

local function update_rays()

    for i = 1, ray_count do
        ray = rays[i]
      
        ray.from.x =  hero.position.x + ray.offset_from.x
        ray.from.y =   hero.position.y + ray.offset_from.y
        ray.to.x = hero.position.x + (ray.offset.x * hero.direction)
        ray.to.y = hero.position.y + ray.offset.y
    end

end

local function on_enter_falling(self, event, from, to, msg)
    -- print("on_enter_falling")
    fall_start_position = go.get_position()
    fall_start_position.y = fall_start_position.y - hero.sprite_bound.y
    sprite.play_flipbook(hero.sprite, hero.anim.FALL)
end

local function on_leave_falling(self, event, from, to, msg)
    -- print("on_leave_falling")

end

local function on_enter_jumping(self, event, from, to, msg)
    -- print("on_enter_jumping")

    hero.velocity.y = JUMP_TAKEOFF_SPEED
    sprite.play_flipbook(hero.sprite, hero.anim.JUMP)

end

local function on_leave_jumping(self, event, from, to, msg)
    if hero.velocity.y > 0 then
        hero.velocity.y = hero.velocity.y * 0.5
    end
end

local function on_enter_standing(self, event, from, to, msg)
    -- print("on_enter_standing")
    hero.velocity.y = 0
    sprite.play_flipbook(hero.sprite, hero.anim.IDLE)
end

local function on_enter_walking(self, event, from, to, msg)
    -- print("on_enter_walking")
    hero.velocity.y = 0

    sprite.play_flipbook(hero.sprite, hero.anim.WALK)

end

local function update_onair_move()
    if (hero.fsm:is("jumping") or hero.fsm:is("falling")) and wall_contact == false then
        hero.velocity.x = MAX_AIR_SPEED * hero.direction

    end
end

local function set_direction(direction)
    hero.direction = direction

    sprite.set_hflip(hero.sprite, hero.direction == -1)
end

local function fsm_init()

    hero.fsm = fsm.create({
        initial = "init",
        -- LuaFormatter off
            events = {    
                {name = "init", from = "*", to = "setting"},
                {name = "idle", from = {"init","walking", "falling"}, to = "standing"},
                {name = "walk", from = {"standing","falling"}, to = "walking"},
                {name = "jump", from = {"standing", "walking"}, to = "jumping"},
                {name = "fall", from = {"standing","walking","jumping"}, to = "falling"},
            },
            callbacks = {
                on_enter_standing = on_enter_standing,
                on_enter_walking = on_enter_walking,
                on_enter_jumping = on_enter_jumping,
                on_leave_jumping = on_leave_jumping,
                on_enter_falling = on_enter_falling,
                on_leave_falling = on_leave_falling
            }
            -- LuaFormatter on
    })
end

local function check_ground(type)
    -- body
end

function hero.update(self, dt)

    if hero.fsm:is("walking") and wall_contact == false then
        hero.velocity.x = MAX_GROUND_SPEED * hero.direction
    end

    -- Let it fall
    if ground_check.BACK == false and ground_check.FRONT == false then
        -- ON AIR
        hero.velocity.y = hero.velocity.y + GRAVITY * dt
        hero.velocity.y = utils.clamp(hero.velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED)

        hero.velocity.x = utils.decelerate(hero.velocity.x, 1, dt)
        hero.velocity.x = utils.clamp(hero.velocity.x, -MAX_AIR_SPEED, MAX_AIR_SPEED)
    else
        -- ON GROUND
        hero.velocity.x = utils.decelerate(hero.velocity.x, 20, dt)
        hero.velocity.x = utils.clamp(hero.velocity.x, -MAX_GROUND_SPEED, MAX_GROUND_SPEED)

    end

    hero.position = hero.position + hero.velocity * dt

    update_rays()

    if manager.debug then
        utils.draw_rays(rays, ray_count)
    end

    -- FRONT RAY 
    ray_hit, ray_tile_x, ray_tile_y, ray_array_id, ray_tile_id, ray_intersection_x, ray_intersection_y, ray_side = raycast.cast(hero.position, rays[2].to)

    if ray_hit then
        ray_intersection.x = ray_intersection_x
        ray_intersection.y = ray_intersection_y

        -- If falling on platform
        if ray_tile_id == manager.tile.FLOAT and hero.fsm:is("falling") and ray_side == 1 and (fall_start_position.y) > (16 * ray_tile_y + 3) and ground_check.FRONT == false then
            oneside_platform_contact = true
            ground_check.FRONT = true
            hero.position.y = 16 * ray_tile_y + hero.sprite_bound.y
            hero.fsm:idle()
        end

        -- If on platform
        if ray_tile_id == manager.tile.FLOAT and ray_side == 1 and oneside_platform_contact == true then
            ground_check.FRONT = true
        else
            oneside_platform_contact = false
        end

        -- If on ground
        if ray_tile_id == manager.tile.WALL and ray_side == 1 and ground_check.FRONT == false then
            ground_check.FRONT = true
            hero.position.y = 16 * ray_tile_y + hero.sprite_bound.y
            hero.fsm:idle()
        end

        if manager.debug then
            utils.draw_hit_point(ray_intersection)
        end
    else
        ground_check.FRONT = false
    end

    -- BACK RAY 
    ray_hit, ray_tile_x, ray_tile_y, ray_array_id, ray_tile_id, ray_intersection_x, ray_intersection_y, ray_side = raycast.cast(hero.position, rays[1].to)

    if ray_hit then
        ray_intersection.x = ray_intersection_x
        ray_intersection.y = ray_intersection_y

        -- If falling on platform
        if ray_tile_id == manager.tile.FLOAT and hero.fsm:is("falling") and ray_side == 1 and (fall_start_position.y) > (16 * ray_tile_y + 3) and ground_check.FRONT == false then
            oneside_platform_contact = true
            ground_check.FRONT = true
            hero.position.y = 16 * ray_tile_y + hero.sprite_bound.y
            hero.fsm:idle()
        end

        -- If on platform
        if ray_tile_id == manager.tile.FLOAT and ray_side == 1 and oneside_platform_contact == true then
            ground_check.FRONT = true
        else
            oneside_platform_contact = false
        end

        -- If on ground
        if ray_tile_id == manager.tile.WALL and ray_side == 1 and ground_check.FRONT == false then
            ground_check.FRONT = true
            hero.position.y = 16 * ray_tile_y + hero.sprite_bound.y
            hero.fsm:idle()
        end

        if manager.debug then
            utils.draw_hit_point(ray_intersection)
        end
    else
        ground_check.BACK = false
    end

    if hero.fsm:is("jumping") and hero.velocity.y < 0 then
        hero.fsm:fall()
    end

    if ground_check.BACK == false and ground_check.FRONT == false and hero.fsm:is("jumping") == false then
        hero.fsm:fall()
    end

    -- WALL RAY 
    ray_hit, ray_tile_x, ray_tile_y, ray_array_id, ray_tile_id, ray_intersection_x, ray_intersection_y, ray_side = raycast.cast(hero.position, rays[3].to)

    if ray_hit then
        ray_intersection.x = ray_intersection_x
        ray_intersection.y = ray_intersection_y
      
        if ray_tile_id == manager.tile.WALL and ray_side == 0 then
            hero.position.x = (16 * (ray_tile_x - (hero.direction == -1 and 0 or 1))) - hero.sprite_bound.x * hero.direction

            wall_contact = true
            -- hero.fsm:idle()
        end

        if manager.debug then
            utils.draw_hit_point(ray_intersection)
        end
    else
        wall_contact = false
    end

    -- FORWARD RAY for one way platforms
    ray_hit, ray_tile_x, ray_tile_y, ray_array_id, ray_tile_id, ray_intersection_x, ray_intersection_y, ray_side = raycast.cast(rays[4].from, rays[4].to)

    if ray_hit then
        ray_intersection.x = ray_intersection_x
        ray_intersection.y = ray_intersection_y

        if ray_hit then
          
            if ray_tile_id == 195    then
               
              hero.position.x = (16 * (ray_tile_x - (hero.direction == -1 and 0 or 1))) - hero.sprite_bound.x * hero.direction
                hero.velocity.x = 0
                wall_contact = true

            end
        end

        if manager.debug then
            utils.draw_hit_point(ray_intersection)
        end
    end

    go.set_position(hero.position)

end

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
            if ground_check.BACK == false and ground_check.FRONT == false then
                hero.fsm:fall()
            end
        end

    end

end

function hero.init()

    hero.url = msg.url(".")
    hero.sprite = msg.url("#hero_sprite")
    hero.position = go.get_position(hero.url)
    hero.sprite_size = go.get(hero.sprite, "size")
    hero.sprite_bound = go.get(hero.sprite, "size") / 2
    hero.direction = 1
    hero.velocity = vmath.vector3(0, 0, 0)

    fsm_init()
    hero.fsm:idle()

end

return hero
