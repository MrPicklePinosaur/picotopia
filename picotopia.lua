pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

#include menu.p8

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
-- { forest={}, game=nil, gold=nil }

players = {
    {tribe='red'},
    {tribe='blue'}
}
current_turn = 'red'

tile_colors = {
    grass={c1=11, c2=3},
    forest={c1=11, c2=3},
    field={c1=11, c2=3},
    mountain={c1=5},
    water={c1=12}
}

units={
    warrior={max_hp=10, cost=2, atk=2, def=2, mv=1, rng=1, skills={'dash', 'fortify'}},
    rider={max_hp=10, cost=3, atk=2, def=1, mv=2, rng=1, skills={'dash', 'escape', 'fortify'}},
}

-- menus
unit_menu = menu_new({
    {unit='warrior'},
    {unit='rider'},
})
unit_menu.visible = false

move_preview = {}

function shuffle(t)
    for i = #t, 2, -1 do
        local j = flr(rnd(i)) + 1
        t[i], t[j] = t[j], t[i]
    end
end

function panic(str)
    cls(0)
    print(str)
    while true do
    end
end

function grid_at(x, y)
    return grid[(y-1)*grid_w+(x-1)+1]
end

function grid_cur()
    return grid_at(cursor_x, cursor_y)
end

function to_screenspace(x, y)
    return {-(y-1)*8+(x-1)*8, (y-1)*4+(x-1)*4}
end

function build_perlin_map(map_w, map_h)

end

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
    
    for i, player in ipairs(players) do
        local cap_x = flr(rnd(quad_w)) + quadrants[i][1]
        local cap_y = flr(rnd(quad_h)) + quadrants[i][2]
        
        -- insert player capital into map
        -- TODO generste a goofy name
        local cell = grid_at(cap_x, cap_y)
        
        cell.building = {kind='city', level=1, tribe=player.tribe, capital=true}
    end
    
end

function spawn_unit(kind, tribe, x, y)
    local cell = grid_at(x, y)
    local new_unit = units[kind]
    new_unit.kind = kind
    new_unit.tribe = tribe
    new_unit.hp = max_hp
    cell.unit = new_unit
end

function _init()
    generate_map()
end

function generate_moves(dist, x, y)
    moves = {}
    for j=-dist,dist do
        for i=-dist,dist do
            local new_x = x+i
            local new_y = y+j
            if new_x >= 1 and new_x <= grid_w and new_y >= 1 and new_y <= grid_h and not (i == 0 and j == 0) then
                add(moves, {new_x, new_y})
            end
        end
    end
    return moves
end

function handle_interact()
    local cell = grid_cur()
    if cell.unit.kind ~= '' and cell.unit.tribe == current_turn then
        move_preview = generate_moves(cell.unit.mv, cursor_x, cursor_y)
    elseif cell.building.kind == 'city' and cell.building.tribe == current_turn then
        -- troop selection menu
        unit_menu.visible = true
    end
end

function _update60()
    if unit_menu.visible then
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
            spawn_unit(unit_menu:cur().unit, current_turn, cursor_x, cursor_y)
        end
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
        elseif btnp(5) then
            -- open relevant menu
            handle_interact()
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
    if tile.kind == 'field' then
        sspr(0, 32, 16, 16, x-7, y-8)
    elseif tile.kind == 'forest' then
        sspr(16, 32, 16, 16, x-7, y-8)
    elseif tile.kind == 'mountain' then
        sspr(48, 32, 16, 16, x-7, y-8)
    end
    
    -- tile resources
    if tile.resource.kind == 'fruit' then
        sspr(32, 32, 16, 16, x-7, y-8)
    elseif tile.resource.kind == 'animal' then
        --sspr(32, 32, 16, 16, x-7, y-8)
    end
    
    draw_building(tile.building, x, y)
    
    draw_unit(tile.unit, x, y)
end

function draw_building(building, x, y)
    if building.kind == 'city' then       
        if building.tribe == 'red' then
            sspr(16, 16, 16, 16, x-7, y-8)
        elseif building.tribe == 'blue' then
            
        end
    end
end

function draw_unit(unit, x, y)
    local c = 5
    if unit.tribe == 'red' then
        c = 8
    elseif unit.tribe == 'blue' then
        c = 12
    end
    
    if unit.kind == 'warrior' then
        spr(0, x-4, y-3)
    elseif unit.kind == 'rider' then
        spr(1, x-4, y-3)
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
        circ(pos[1], pos[2], 4, 0)
        circ(pos[1], pos[2], 3, 12)
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
        
        if building.kind == 'city' then
            x = print(' ['..building.tribe..']', x, 120, 6)
        end
    end
    
    local pos = tostring(cursor_x)..','..tostring(cursor_y)
    print(pos, 125-4*#pos, 120, 7)
    
    -- menus
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
0448dd8004499d0008dd440008d555506668dd800888880600000000000000000000000000000000000000000000000000000000000000000000000000000000
004499d0004886000d99d4000d952850066d99d00444466000000000000000000000000000787000000000000000000000000000000000000000000000000000
0004880000048660008444460085285000dd88005555555500000000000000400000000000778700078700000000000000000000000000000000000000000000
00004800066dd60000880400008528500000d8005888885078700000000000470000000000078700007870000000000000000000000000000000000000000000
0000dd000066660000dd440000dd55000000dd000555550007870000000000477000000000078700007870000060008000008000000000000000000000000000
00000000006006000000400000000000000000000000000007870000000000477700000000078700007870000066008880888000000000000000000000000000
0000000000000000000000000000000000000000000000000787000000000047777000000007778800777000006d6008ddd80000000000000000000000000000
00000000000000000000000000000000000000000000000007778008000000478778000000009888800900000006d60d090d0000000000000000000000000000
00000000000000000000000000000000000000000000000000408dd8000000478dd87000000090440009000000006d6099900000000000000000000000000000
0000000000000000000000000000000000000000000000000040d99d00000040d99d000000088888888888000000066d88800000000000000000000000000000
0000000000000000000000000000000000000000000000000088888800008888888800000000444444444000000000dd88800000000000000000000000000000
000000000000000000000000000000000000000000000000008888880000888888800000000044545454000000000000d8800000000000000000000000000000
00000000000000000000000000000000000000000000000000044440000004444400000000000444444000000000000050500000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000x 
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
00000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000e0000000000000000000000000000067700000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000eee000000000000000000000000000067700000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000e0040000000000000000000000000000667770000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000eee040e00000000000000000000000000667d70000000000000000000000000000000000000000000000000000000000000000000000
000000033000000000e004000eee0e00000009300000000000006d57d57000000000000000000000000000000000000000000000000000000000000000000000
00000330033000000eee040e0040eee00000099003900000000dd555d55d00000000000000000000000000000000000000000000000000000000000000000000
0003300330033000004000eee040040000000440099000000d55d55ddd55d5500000000000000000000000000000000000000000000000000000000000000000
0000033003300000000000040000000000000000044000000dd555d5d5d5ddd00000000000000000000000000000000000000000000000000000000000000000
000000033000000000000004000000000000000000000000000dd5d5d55dd0000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000dd5ddd000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000dd00000000000000000000000000000000000000000000000000000000000000000000000

