pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

#include menu.p8
#include util.p8

-- map sizes 11, 14, 16, 18, 20 or 30
grid_w = 16
grid_h = 16
grid = {

}

cursor_x=flr(grid_w/2)
cursor_y=flr(grid_h/2)

-- grid item
-- { kind = 'grass|forest|water|deep-water|mountain', building={},

-- building
buildings = {
    port={kind='port', cost=7},
    lumber={kind='lumber hut', cost=3},
    farm={kind='farm', cost=5},
}
-- {kind='city', level=1, tribe=<tribe>, capital=true}

tech = {
    hunting=true,
    forestry=true,
    archery=true,

    fishing=true,
    ramming=true,
    sailing=true,

    climbing=true,
    mining=true,

    organization=true,
    farming=true,
    strategy=true,

    riding=true,
}

-- spritesheet is index of player specific spritesheet in memory
players = {
    {tribe='red', camera={0, 0}, coins=100, tech=clone_table(tech)},
    {tribe='blue', camera={0, 0}, coins=100, tech=clone_table(tech)},
    -- white={tribe='white', spritesheet=2},
    -- yellow={tribe='yellow', spritesheet=3},
}
current_turn = 1

tile_colors = {
    grass={c1=11, c2=3},
    forest={c1=11, c2=3},
    field={c1=11, c2=3},
    mountain={c1=5},
    water={c1=12}
}

units={
    warrior={max_hp=10, cost=2, atk=2, def=2, mv=1, rng=1, skills={dash=true, fortify=true}},
    rider={max_hp=10, cost=3, atk=2, def=1, mv=2, rng=1, skills={dash=true, escape=true, fortify=true}},
    raft={max_hp=0, cost=0, atk=0, def=2, mv=2, rng=2, skills={float=true, carry=true}},
}

-- menus
action_menu = menu_new({
    {label='move', fn=function()end},
    {label='upgrade', fn=function()end},
    {label='finish', fn=function()
        on_end_turn()

        current_turn = (current_turn % #players) + 1

        on_start_turn()
    end},
})
action_menu.visible = true

-- menu to show all possible actions on a tile
tile_menu = menu_new({})
tile_menu.visible = false

-- TODO filter down the ones we can actually spawn
unit_menu = menu_new({
    {unit='warrior'},
    {unit='rider'},
})
unit_menu.visible = false

upgrade_menu = menu_new({})
upgrade_menu.visible = false

move_preview = {}
-- the position of the unit we wish to move
move_unit_pos = nil

-- cursor mode = interact|move
cursor_mode = 'interact'

-- helpers
function grid_at(x, y)
    return grid[(y-1)*grid_w+(x-1)+1]
end

function grid_cur()
    return grid_at(cursor_x, cursor_y)
end

function current_player()
    return players[current_turn]
end

function current_tribe()
    return players[current_turn].tribe
end

function current_tech()
    return players[current_turn].tech
end

-- check if the current player has at least this amount of coins
function has_coins(amount)
    return players[current_turn].coins >= amount
end

function spend_coins(amount)
    players[current_turn].coins = max(0, players[current_turn].coins-amount)
end

function to_screenspace(x, y)
    return {-(y-1)*8+(x-1)*8, (y-1)*4+(x-1)*4}
end

function get_spriteoffset(tribe)
    -- need to search for the tribe
    for i, player in ipairs(players) do
        if player.tribe == tribe then
            return (i-1) * 48
        end
    end
    printh('get_spriteoffset failed to find tribe '..tribe)
    return 0
end

-- generate coins depending on the state of the city
function generate_coins(city)
    local coins = city.level + 1
    if city.capital then
        coins += 1
    end
    return coins
end

function on_start_turn()
    -- restore camera position
    cursor_x, cursor_y = unpack(players[current_turn].camera)

    -- reset UI / state
    action_menu.visible = true
    cursor_mode = 'interact'

    -- TODO sadly we need to look through the whole map for now
    for _, tile in ipairs(grid) do
        
        -- restore unit moved
        if tile.unit.kind ~= nil and tile.unit.tribe == current_tribe() then
            tile.unit.can_move = true
        end

        -- produce money from cities
        -- TODO no money if enemy unit on the city
        if tile.building.kind == 'city' and tile.building.tribe == current_tribe() then
            -- TODO play animation
            current_player().coins += generate_coins(tile.building)
        end

    end

end

function on_end_turn()
    -- save current camera position
    players[current_turn].camera = {cursor_x, cursor_y}
end

function build_perlin_map(map_w, map_h)

end

-- check if there is a city in a 5x5 box
function cities_in_range(x, y)
    for j=-2,2 do
        for i=-2,2 do
            local cell = grid_at(x+i, y+j)
            if cell ~= nil and cell.building.kind == 'city' then
                return true
            end
        end
    end
    return false
end

-- mapgen
function generate_map()
    for j=1,grid_h do
        for i=1,grid_w do
            if rnd(1) > 0.2 then
                local new_tile = add(grid, {kind='grass', building={}, unit={}, resource={}})
                -- if grass choose a random resource type
                local roll = rnd(1)
                if roll > 0.85 then
                    new_tile.kind = 'forest'
                    if rnd(1) > 0.8 then
                       new_tile.resource.kind = 'animal'
                    end
                elseif roll > 0.7 then
                    new_tile.kind = 'mountain'
                elseif roll > 0.6 then
                    new_tile.kind = 'field'
                else
                    if rnd(1) > 0.9 then
                       new_tile.resource.kind = 'fruit'
                    end
                end
            else
                add(grid, {kind='water', building={}, unit={}, resource={}})
            end
        end
    end
    
    -- perlin noise
    
    -- choose capital locations, then force 3x3 to be land
    -- split map into 4 'domains and randomly choose one for each player'
    local quad_pad = 2
    local quad_w = flr(grid_w / 2) - quad_pad*2
    local quad_h = flr(grid_h / 2) - quad_pad*2
    local quadrants = {
        {quad_pad, quad_pad},
        {quad_pad, grid_h-quad_pad-quad_h},
        {grid_w-quad_pad-quad_w, quad_pad},
        {grid_w-quad_pad-quad_w, grid_h-quad_pad-quad_h}
    }

    shuffle(quadrants)
    
    local capitals = {}
    for i, player in ipairs(players) do
        local cap_x = flr(rnd(quad_w)) + quadrants[i][1]
        local cap_y = flr(rnd(quad_h)) + quadrants[i][2]
        
        -- insert player capital into map
        -- TODO generste a goofy name
        local cell = grid_at(cap_x, cap_y)
        -- capitals must be on grassland
        cell.kind = 'grass'
        cell.building = {kind='city', level=1, tribe=player.tribe, capital=true}
        add(capitals, {x=cap_x, y=cap_y, tribe=player.tribe})

        -- set player starting location to capital
        player.camera = {cap_x, cap_y}
    end
    
    -- assign all cells to be of tribe its closest to
    for j=1,grid_h do
        for i=1,grid_w do
            -- gotta do all this manually TT
            local closest_cap = nil
            local small_d = 1000
            for _, cap in ipairs(capitals) do
                local d = sqrt((j-cap.y)^2+(i-cap.x)^2)
                if d < small_d then
                    small_d = d
                    closest_cap = cap.tribe
                end
            end
            grid_at(i, j).tribe = closest_cap
        end
    end

    -- spawn a handfull of more villages (ensuring that it's not too close to another village)
    -- no village in 5x5
    for j=1,grid_h do
        for i=1,grid_w do
            local cell = grid_at(i, j)
            if cell.kind == 'grass' and cell.building.kind == nil and not cities_in_range(i, j) then
                if rnd(1) > 0.5 then
                    cell.building = {kind='city', level=0, tribe=nil, capital=false}
                end
            end
        end
    end
end

function spawn_unit(kind, tribe, x, y)
    local cell = grid_at(x, y)
    local new_unit = clone_table(units[kind])
    new_unit.kind = kind
    new_unit.tribe = tribe
    new_unit.hp = new_unit.max_hp
    new_unit.can_move = false -- all units can't move when spawned (unless has special trait)

    cell.unit = new_unit
end

function kill_unit(pos)
    local cell = grid_at(unpack(pos))
    cell.unit = {}
end

function request_move_unit(unit_pos)
    move_unit_pos = unit_pos
    local cell = grid_at(unpack(move_unit_pos))

    -- only allow unit to move if 
    move_preview = generate_moves(cell.unit, unpack(unit_pos))
    if cell.unit.can_move then
        move_preview = generate_moves(cell.unit, unpack(unit_pos))
    else
        move_preview = {}
    end
end

function cancel_move_unit()
    move_unit_pos = nil
    move_preview = {}
end

function confirm_move_unit(new_pos)
    local cell = grid_at(unpack(move_unit_pos))
    local unit_temp = cell.unit
    unit_temp.can_move = false -- only move once per turn
    cell.unit = {}
    grid_at(unpack(new_pos)).unit = unit_temp
    cancel_move_unit()

    on_unit_move(new_pos)
end

-- runs after the unit is moved to a new tile
function on_unit_move(pos)

    local cell = grid_at(unpack(pos))

    -- check if the unit should be converted to a boat unit if it lands on a port
    -- TODO check that we own the port
    if cell.building.kind == 'port' and cell.unit.skills.float == nil then
        local unit_copy = clone_table(cell.unit)
        spawn_unit('raft', current_tribe(), pos[1], pos[2])
        cell.unit.max_hp = unit_copy.max_hp
        cell.unit.hp = unit_copy.hp
        cell.unit.carry = unit_copy -- used to restore the unit after disembarking
    end

    -- if we are a unit with the 'carry' skill, we disembark when reaching land
    if cell.unit.skills.carry == true and not is_water_tile(cell) then
        local cur_hp = cell.unit.hp
        local unit_copy = clone_table(cell.unit.carry)
        cell.unit = unit_copy
        cell.unit.hp = cur_hp
    end

end

function confirm_attack_unit(enemy_pos)
    -- determine participating units
    local attacking = grid_at(unpack(move_unit_pos)).unit
    local defending = grid_at(unpack(enemy_pos)).unit

    -- compute the damage
    -- formulae from https://polytopia.fandom.com/wiki/Combat
    local attack_force = attacking.atk * (attacking.hp / attacking.max_hp)
    -- TODO include defending bonus
    local def_bonus = 1
    local defence_force = defending.def * (defending.hp / defending.max_hp) * def_bonus
    local total_damage = attack_force + defence_force

    local attack_res = round((attack_force / total_damage) * attacking.atk * 4.5)
    local defence_res = round((defence_force / total_damage) * defending.def * 4.5)

    -- apply the damage
    defending.hp = max(0, defending.hp - attack_res)
    printh('attacker dealt '..tostring(attack_res)..' damage, defender has '..tostring(defending.hp)..'/'..tostring(defending.max_hp))
    if defending.hp <= 0 then

        kill_unit(enemy_pos)

        -- if we kill the enemy, do we move to take it's place?
        -- TODO more complex behavior that respects movement rules, ie don't move into water
        confirm_move_unit(enemy_pos)
    end

    attacking.hp = max(0, attacking.hp - defence_res)
    printh('defernder dealt '..tostring(defence_res)..' damage, attacker has '..tostring(attacking.hp)..'/'..tostring(attacking.max_hp))
    if attacking.hp <= 0 then
        kill_unit(move_unit_pos)
    end

    cancel_move_unit()
end

function _init()
    generate_map()

    -- TEMP setup scenario
    spawn_unit('rider', 'red', 8, 8)
    spawn_unit('rider', 'blue', 8, 9)

    ----------

    on_start_turn()
end

function cell_attack_rules(cell, x, y)
    return true
end

function is_water_tile(cell)
    return (cell.kind == 'water' or cell.kind == 'deep-water')
end

-- return true or false if the cell is allowed to be moved to
function cell_move_rules(unit, cell, x, y)
    -- stay within bounds of map
    if x < 1 or x > grid_w or y < 1 or y > grid_h then
        return false
    end

    -- don't allow moving in water (that are not ports) IF the unit doesn't have float
    if is_water_tile(cell) and cell.building.kind ~= 'port' and unit.skills.float == nil then
        return false
    end

    -- only move to mountains if tech is unlocked
    if cell.kind == 'mountain' and not current_tech().climbing then
        return false
    end

    return true
end

function generate_moves(unit, x, y)
    local mv_dist = unit.mv
    local atk_dist = unit.rng

    local dist = max(mv_dist, atk_dist)

    moves = {}
    for j=-dist,dist do
        for i=-dist,dist do
            local new_x = x+i
            local new_y = y+j
            local new_cell = grid_at(new_x, new_y)

            if not (i == 0 and j == 0) then
                -- attack takes precedence
                if (i >= -atk_dist and i <= atk_dist and j >= -atk_dist and j <= atk_dist) and cell_attack_rules(new_cell, new_x, new_y) and new_cell.unit.kind ~= nil and new_cell.unit.tribe ~= current_tribe() then
                    add(moves, {new_x, new_y, kind='attack'})
                elseif (i >= -mv_dist and i <= mv_dist and j >= -mv_dist and j <= mv_dist) and cell_move_rules(unit, new_cell, new_x, new_y) then
                    add(moves, {new_x, new_y, kind='move'})
                end
            end
        end
    end
    return moves
end

function update_action_menu()
    if btnp(2) then
        action_menu:up()
    elseif btnp(3) then
        action_menu:down()
    elseif btnp(5) then
        action_menu.visible = false
        action_menu:cur().fn()
    end
end

function update_tile_menu()
    if btnp(2) then
        tile_menu:up()
    elseif btnp(3) then
        tile_menu:down()
    elseif btnp(5) then
        tile_menu.visible = false
        tile_menu:cur().fn()
    end
end

function update_unit_menu()
    if btnp(2) then
        unit_menu:up()
    elseif btnp(3) then
       unit_menu:down()
    elseif btnp(4) then
        unit_menu.visible = false
    elseif btnp(5) then
        unit_menu.visible = false
        -- spawn unit
        -- TODO take resource in account
        local unit = unit_menu:cur().unit
        if has_coins(units[unit].cost) then
            spawn_unit(unit, current_tribe(), cursor_x, cursor_y)
            spend_coins(units[unit].cost)
        end
    end
end

-- handle clicking when in interact mode
function handle_cursor_interact()
    local cell = grid_cur()

    -- show menu for all possible interactions
    local tile_menu_items = {}

    -- move unit if there is one
    if cell.unit.kind ~= nil and cell.unit.tribe == current_tribe() then
        add(tile_menu_items, {label='mobolize troop', auto=true, fn=function()
            request_move_unit({cursor_x, cursor_y})
            -- TODO sanity check that we have valid moves
            cursor_mode = 'move'
        end})

    end

    -- interact with city if no unit on top
    if cell.building.kind == 'city' and cell.building.tribe == current_tribe() and cell.unit.kind == nil then
        add(tile_menu_items, {label='train troops', auto=true, fn=function()
            -- troop selection menu
            unit_menu.visible = true
        end})
    end

    -- capture city if unit can still move
    -- TODO might be problematic for units that can move twice?
    -- should technically implement feature that unit needs to have arrived to this city
    -- last turn
    if cell.building.kind == 'city' and cell.building.tribe ~= current_tribe() and cell.unit.kind ~= nil and cell.unit.can_move then
        add(tile_menu_items, {label='capture city', auto=false, fn=function()
            cell.building.tribe = current_tribe() 
            -- promote villages into level 1 cities
            if cell.building.level == 0 then
                cell.building.level = 1
            end
            -- this uses a unit's move
            cell.unit.can_move = false
        end})
    end

    -- TODO also check inside territory
    -- TODO can make building code less repetitive?
    if current_tech().forestry and cell.kind == 'forest' and cell.building.kind == nil then
        add(tile_menu_items, {label='build lumber hut', auto=false, fn=function()
            if has_coins(buildings.lumber.cost) then
                cell.building = clone_table(buildings.lumber)
                cell.kind = 'grass' -- converts forest into grassland
                spend_coins(buildings.lumber.cost)
            end
        end})
    end

    if  current_tech().farming and cell.kind == 'field' and cell.building.kind == nil then
        add(tile_menu_items, {label='build farm', auto=false, fn=function()
            if has_coins(buildings.lumber.farm) then
                cell.building = clone_table(buildings.farm)
                spend_coins(buildings.farm.cost)
            end
        end})
    end

    if current_tech().fishing and cell.kind == 'water' and cell.building.kind == nil then
        add(tile_menu_items, {label='build port', auto=false, fn=function()
            if has_coins(buildings.port.cost) then
                cell.building = clone_table(buildings.port)
                spend_coins(buildings.port.cost)
            end
        end})
    end

    -- ignore if there are no interactions
    if #tile_menu_items == 0 then
        return
    end

    -- automatically accept the action if there is only one option
    if #tile_menu_items == 1 and tile_menu_items[1].auto then
        tile_menu_items[1].fn()
        return
    end

    add(tile_menu_items, {label='cancel', fn=function()
        tile_menu.visible = false
    end})

    tile_menu = menu_new(tile_menu_items)
    tile_menu.visible = true
end

-- handle clicking when in unit move mode
function handle_cursor_move()
    -- check if move location is valid
    for _, pos in ipairs(move_preview) do
        if pos[1] == cursor_x and pos[2] == cursor_y then
            -- move the unit or use it to attack
            if pos.kind == 'move' then
                confirm_move_unit({cursor_x, cursor_y})
            elseif pos.kind == 'attack' then
                -- calculate damage exchange
                confirm_attack_unit({cursor_x, cursor_y})
            end
            cursor_mode = 'interact'
        end
    end
    -- TODO not valid, do some animation?
end

function _update60()
    if action_menu.visible then
        update_action_menu()
    elseif tile_menu.visible then
        update_tile_menu()
    elseif unit_menu.visible then
        update_unit_menu()
    else
        -- move camera
        if btnp(0) then
            cursor_x = max(1, cursor_x-1)
        elseif btnp(1) then
            cursor_x = min(grid_w, cursor_x+1)
        elseif btnp(2) then
            cursor_y = max(1, cursor_y-1)
        elseif btnp(3) then
            cursor_y = min(grid_h, cursor_y+1)
        elseif btnp(4) then
            action_menu.visible = true
            cursor_mode = 'interact'
        elseif btnp(5) then
            -- open relevant menu
            if cursor_mode == 'interact' then
                handle_cursor_interact()
            elseif cursor_mode == 'move' then
                handle_cursor_move()
            end
        end
    end
end

function draw_map()
    for j=1,grid_h do
        for i=1,grid_w do
            -- determine color to user 
            draw_tile(grid_at(i, j), unpack(to_screenspace(i, j)))
        end
    end
    
    
    -- TODO might want to draw all buildings after cursor
end

-- x,y - position of top pixel of tile
function draw_tile(tile, x, y)
    -- determine color of tile
    -- TODO assuming valid tile kind
    local c1 = tile_colors[tile.kind].c1 or 5
    local c2 = tile_colors[tile.kind].c2
    
    for i=0,3 do
        line(x-2*i, y+i, x+1+2*i, y+i, c1)
        line(x-2*i, y+7-i, x+1+2*i, y+7-i, c1)
    end
    
    -- c2 is bottom border
    if c2 ~= nil then
        line(x-6, y+4, x+1, y+7, c2)
        line(x+7, y+4, x, y+7, c2)
    end
 
    -- detailed tiles
    local sprite_offset = get_spriteoffset(tile.tribe)
    
    if tile.kind == 'field' then
        sspr(0, 32+sprite_offset, 16, 16, x-7, y-8)
    elseif tile.kind == 'forest' then
        sspr(16, 32+sprite_offset, 16, 16, x-7, y-8)
    elseif tile.kind == 'mountain' then
        sspr(64, 32+sprite_offset, 16, 16, x-7, y-8)
    end
    
    -- tile resources
    if tile.resource.kind == 'fruit' then
        sspr(32, 32+sprite_offset, 16, 16, x-7, y-8)
    elseif tile.resource.kind == 'animal' then
        sspr(48, 32+sprite_offset, 16, 16, x-7, y-8)
    end
    
    draw_building(tile.building, x, y, tile.tribe)
    
    if tile.unit.kind ~= nil then
        draw_unit(tile.unit, x, y)
    end
end

function draw_building(building, x, y, tribe)
    local sprite_offset = get_spriteoffset(tribe)

    if building.kind == 'city' then       
        local level_offset = building.level * 16
        sspr(level_offset, 16+sprite_offset, 16, 16, x-7, y-8)
    elseif building.kind == 'lumber hut' then
        sspr(0, 96, 16, 16, x-7, y-8)
    elseif building.kind == 'farm' then
        sspr(16, 96, 16, 16, x-7, y-8)
    elseif building.kind == 'port' then
        sspr(32, 96, 16, 16, x-7, y-8)
    end
end

function draw_unit(unit, x, y)
    local sprite_offset = get_spriteoffset(unit.tribe)

    if unit.kind == 'warrior' then
        sspr(0, sprite_offset, 8, 8, x-4, y-3)
    elseif unit.kind == 'rider' then
        sspr(8, sprite_offset, 8, 8, x-4, y-3)
    elseif unit.kind == 'raft' then
        sspr(48, sprite_offset, 8, 16, x-4, y-11)
    end
end

-- draw cursor at specific pixel value
function draw_cursor(px, py)
    local cursor_c = 7
    line(px-8, py+3, px+1, py-1, cursor_c)
    line(px+9, py+3, px, py-1, cursor_c)
    line(px-6, py+4, px+1, py+7, cursor_c)
    line(px+7, py+4, px, py+7, cursor_c)
end

function draw_map_ui()
    -- move preview
    for i, cell in ipairs(move_preview) do
        local pos = to_screenspace(unpack(cell))
        local c = 0
        if cell.kind == 'move' then
            c = 12
        elseif cell.kind == 'attack' then
            c = 8
        end

        circ(pos[1], pos[2], 4, 0)
        circ(pos[1], pos[2], 3, c)
    end
end

function draw_hud()

    -- bottom bar showing the current selected tile
    line(0, 116, 128, 116, 7)
    line(0, 117, 128, 117, 0)
    rectfill(0, 118, 128, 128, 1)
    
    local cell = grid_at(cursor_x, cursor_y)
    local x = 3
    x = print(cell.kind, x, 120, 7)
    
    local building = cell.building
    if building.kind ~= nil then 
        x = print(', '.. building.kind, x, 120, 7)
        
        if building.kind == 'city' and building.tribe ~= nil then
            x = print(' ['..building.tribe..']', x, 120, 6)
        end
    end
    
    local pos = tostring(cursor_x)..','..tostring(cursor_y)
    print(pos, 125-4*#pos, 120, 7)

    -- draw current turn
    print('current turn '..current_tribe(), 0, 0, 7)
    print('coins '..tostring(players[current_turn].coins))
    
    -- menus
    if action_menu.visible then
        rect(31, 19, 97, 61, 7)
        rectfill(32, 20, 96, 60, 1)

        for i, item in ipairs(action_menu.items) do
            local c = 6
            if (action_menu:index() == i) c = 7
            print(item.label, 36, 30+(i-1)*8, c)
        end
    end
    
    if tile_menu.visible then
        rect(31, 19, 97, 61, 7)
        rectfill(32, 20, 96, 60, 1)
        
        for i, item in ipairs(tile_menu.items) do
            local c = 6
            if (tile_menu:index() == i) c = 7
            print(item.label, 36, 30+(i-1)*8, c)
        end
    end

    if unit_menu.visible then
        rect(31, 19, 97, 61, 7)
        rectfill(32, 20, 96, 60, 1)
        
        for i, item in ipairs(unit_menu.items) do
            local c = 6
            if (unit_menu:index() == i) c = 7
            print(item.unit, 36, 30+(i-1)*8, c)
        end
    end
    
end

function _draw()
    cls(0)
    local x = -(cursor_y-1)*8+(cursor_x-1)*8
    local y = (cursor_y-1)*4+(cursor_x-1)*4
    camera(x-64, y-64)
    draw_map()
    draw_map_ui()
    
    camera()
    draw_cursor(64, 64)
    
    draw_hud()
end

__gfx__
00000000448008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04480080448dd8000800400008050050660800800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0448dd8004499d0008dd440008d555506668dd800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
004499d0004886000d99d4000d952850066d99d00000000000000000000000000000000000787000000000000000000000000000000000000000000000000000
0004880000048660008444460085285000dd88000000000000000000000000400000000000778700078700000000000000000000000000000000000000000000
00004800066dd60000880400008528500000d8000000000078700000000000470000000000078700007870000000000000000000000000000000000000000000
0000dd000066660000dd440000dd55000000dd000000000007870000000000477000000000078700007870000060008000008000000000000000000000000000
00000000006006000000400000000000000000000000000007870000000000477700000000078700007870000066008880888000000000000000000000000000
0000000000000000000000000000000000000000000000000787000000000047777000000007778800777000006d6008ddd80000000000000000000000000000
00000000000000000000000000000000000000000000000007778008000000478778000000009888800900000006d60d090d0000000000000000000000000000
00000000000000000000000000000000000000000888880600408dd8000000478dd87000000090440009000000006d6099900000000000000000000000000000
0000000000000000000000000000000000000000044446600040d99d00000040d99d000000088888888888000000066d88800000000000000000000000000000
0000000000000000000000000000000000000000555555550088888800008888888800000000444444444000000000dd88800000000000000000000000000000
000000000000000000000000000000000000000058888850008888880000888888800000000044545454000000000000d8800000000000000000000000000000
00000000000000000000000000000000000000000555550000044440000004444400000000000444444000000000000050500000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000080080000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000009080080900000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000008008000000000000989989000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000080080000000000008888000000000000088880000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000088880000000000088888800000000000888888000000000000000000000000000000000000
00000000000000000000000000000000000008008000000000000888888000000000888888880000000008888888800000000000000000000000000000000000
00000000000000000000000000000000000000880000000000008888888800000008888668888000000000056650000000000000000000000000000000000000
00000099000000000000008800000000000008888000000000000056650000000000005555000000000008888888800000000000000000000000000000000000
00000999900000000000088880000000000088888800000000000055550880000000088888888000000000566665000000000000000000000000000000000000
00000044009900000000006600880000000005665088000000000056658888000000005665888800000088888888880000000000000000000000000000000000
00000000099990000000000008888000000000000888800000000000088888800000008808888880000000566665000000000000000000000000000000000000
00000000004400000000000000660000000000000066000000000000005665000000088880566500000000004400000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000006600000000000000004400000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004400000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000
000000000000000000000000e0000000000000000000000000000000000000000000006770000000000000000000000000000000000000000000000000000000
00000000000000000000000eee000000000000000000000000000000000000000000006770000000000000000000000000000000000000000000000000000000
000000000000000000000e0040000000000000000000000000000000000000000000066777000000000000000000000000000000000000000000000000000000
00000000000000000000eee040e000000000000000000000000000000600000000000667d7000000000000000000000000000000000000000000000000000000
000000033000000000e004000eee0e000000093000000000000000000660000000006d57d5700000000000000000000000000000000000000000000000000000
00000330033000000eee040e0040eee000000990039000000000066666000000000dd555d55d0000000000000000000000000000000000000000000000000000
0003300330033000004000eee0400400000004400990000000000066660000000d55d55ddd55d550000000000000000000000000000000000000000000000000
00000330033000000000000400000000000000000440000000000060060000000dd555d5d5d5ddd0000000000000000000000000000000000000000000000000
0000000330000000000000040000000000000000000000000000000000000000000dd5d5d55dd000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000dd5ddd00000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000dd0000000000000000000000000000000000000000000000000000000
0008800044a88a000088000000880000000088000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44a88a0044aaaa000a8840000a855550660a88a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44aaaa0004499a000aaa44000aa5cc50666aaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04499a00004cc5000a99a4000a95cc50066d99a00000000000000000000000000000000000777000000000000000000000000000000000000000000000000000
004cc0000004c55000c4444600c5cc5000ddcc0000000000000000000000004000000000007c7000077700000000000000000000000000000000000000000000
0004c000055dd50000cc040000c5cc500000dc0077700000777000000000004700000000007c770007c700000000000000000000000000000000000000000000
000dd0000055550000dd440000dd55000000dd007c7000007c70000000000047700000000007c700007c70000000000088800000000000000000000000000000
000000000050050000004000000000000000000007c7000007c7000000000047770000000007c700007c70000099000a888a0000000000000000000000000000
00000000000000000000000000000000000000000777000007c7088000000047788000000007772200777000009a900aaaaa0000000000000000000000000000
0000000000000000000000000000000000000000004000000777a88a00000047a88a000000009222200900000009a90a090a0000000000000000000000000000
0000000000000000000000000000000000000000022222060040aaaa00000047aaaa7000000090440009000000009a9099900000000000000000000000000000
0000000000000000000000000000000000000000044446600040a99a00000040a99a00000002222222222200000009adccc00000000000000000000000000000
0000000000000000000000000000000000000000555555550044444400004444444400000000444444444000000000ddccc00000000000000000000000000000
000000000000000000000000000000000000000052222250004222240000422222400000000044545454000000000000dcc00000000000000000000000000000
00000000000000000000000000000000000000000555550000044440000004444400000000000444444000000000000050500000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000ccc000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000c00000000000000c6c0000000000000000ccc00000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000ccc0000000000000ddd000000000000000cc6cc0000000000000000000000000000000000000
0000000000000000000000000000000000000c00000000000000666000000000000066600000000000000cc666cc000000000000000000000000000000000000
000009900000000000000440000000000000ccc0000000000000ddd0000000000000ddd00ccc00000000cc66666cc00000000000000000000000000000000000
0000999900000000000044440000000000006660000000000000666000c0000000006660ccccc0000000c9d6d6d9c00000000000000000000000000000000000
0000044009900000000006600440000000006d600440000000006d600ccc000000006d6066666000000096999996900000000000000000000000000000000000
000000009999000000000000444400000000000044440000000000000ddd000000000440d0d0d000000006565656000000000000000000000000000000000000
00000000044000000000000006600000000000000660000000000000066600000000444460606000000006564656000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000066000000000000000004000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000030000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000
00000000000000000000000030000000000000000000000000000000000000000000007770000000000000000000000000000000000000000000000000000000
00000000000000000000030030000000000000000000000000000000000000000000077777000000000000000000000000000000000000000000000000000000
00000000000000000000030040300000000000000000000000000000050000000000d777d7770000000000000000000000000000000000000000000000000000
0000000330000000003003000030030000000830000000000000000005500000000d7d57d5ddd000000000000000000000000000000000000000000000000000
000003300330000000300403003003000000088003800000000005555500000000ddd555d55d5d00000000000000000000000000000000000000000000000000
00033003300330000040000300400400000004400880000000000055550000000d55d55ddd5555d0000000000000000000000000000000000000000000000000
00000330033000000000000300000000000000000440000000000050050000000dd555d5d5d5ddd0000000000000000000000000000000000000000000000000
0000000330000000000000040000000000000000000000000000000000000000000dd5d5d55dd000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000dd5ddd00000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000dd0000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000028000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000002228800000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000006667700000000000990000000000004009999000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000006667700000000099009900000000004999949000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00004440000000000009900990099000000099999040000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000222000000000000099009900000000099940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000990000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
