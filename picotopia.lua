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
-- { kind = 'grass|forest|water|deep-water|mountain', building={}, resource={}
--   

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
    water={c1=12}
}

-- menus
unit_menu = menu_new({
    {unit='warrior'},
    {unit='rider'},
})
unit_menu.visible = false

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

function build_perlin_map(map_w, map_h)

end

function generate_map()
    for j=1,grid_h do
        for i=1,grid_w do
            if rnd(1) > 0.2 then
                local new_tile = add(grid, {kind='grass', building={}})
                -- if grass choose a random resource type
                local roll = rnd(1)
                if roll > 0.8 then
                    -- TODO fix resources
                    new_tile.kind = 'forest'
                end
            else
                add(grid, {kind='water', building={}})
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

function _init()
    generate_map()
end

function handle_interact()
    local cell = grid_cur()
    if cell.building.kind == 'city' and cell.building.tribe == current_turn then
        -- troop selection menu
        unit_menu.visible = true
    end
end

function _update60()
    if unit_menu.visible then
        if btnp(2,1) then
            unit_menu:up()
        elseif btnp(3,1) then
            unit_menu:down()
        elseif btnp(4,1) then
            unit_menu.visible = false
        end
    else
        -- move camera
        if btnp(0,1) then
            cursor_x = max(1, cursor_x-1)
        elseif btnp(1,1) then
            cursor_x = min(grid_w, cursor_x+1)
        elseif btnp(2,1) then
            cursor_y = max(1, cursor_y-1)
        elseif btnp(3,1) then
            cursor_y = min(grid_h, cursor_y+1)
        elseif btnp(5,1) then
            -- open relevant menu
            handle_interact()
        end
    end
end

function draw_map()
    for j=1,grid_h do
        for i=1,grid_w do
            -- determine color to use
            
            local x = -(j-1)*8+(i-1)*8
            local y = (j-1)*4+(i-1)*4
            draw_tile(grid_at(i, j), x, y)
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
 
    if tile.kind == 'forest' then
        -- placeholder art
        circfill(x, y+4, 4, 7)
    end
    
    draw_building(tile.building, x, y)
end

function draw_building(building, x, y)
    
    if building.kind == 'city' then       
        local c = 5
        if building.tribe == 'red' then
            c = 8
        elseif building.tribe == 'blue' then
            c = 12
        end
        rectfill(x-2, y+2, x+2, y+6, c)
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

function draw_ui()

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
            print(item.unit, 36, 30, 7, c)
        end
    end
    
end

function _draw()
    cls(0)
    local x = -(cursor_y-1)*8+(cursor_x-1)*8
    local y = (cursor_y-1)*4+(cursor_x-1)*4
    camera(x-64, y-64)
    draw_map()
    
    camera()
    draw_cursor(64, 64)
    
    draw_ui()
end