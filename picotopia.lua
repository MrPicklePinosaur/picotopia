pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

-- map sizes 11, 14, 16, 18, 20 or 30
grid_w = 16
grid_h = 16
grid = {

}

-- grid item
-- { kind = 'grass|water|deep-water|mountain', buildings={}
--   

-- building
-- { forest={}, game=nil, gold=nil }

players = {
    {tribe='red'},
    {tribe='blue'}
}

tile_colors = {
    grass={c1=11, c2=3},
    water={c1=12}
}

function shuffle(t)
    for i = #t, 2, -1 do
        local j = flr(rnd(i)) + 1
        t[i], t[j] = t[j], t[i]
    end
end

function grid_at(x, y)
    return grid[y*grid_w+x]
end

function build_perlin_map(map_w, map_h)

end

function generate_map()
    for j=0,grid_h do
        for i=0,grid_w do
            if rnd(1) > 0.2 then
                local new_tile = add(grid, {kind='grass', buildings={}})
                -- if grass choose a random resource type
                local roll = rnd(1)
                if roll > 0.8 then
                    add(new_tile.buildings, {kind='forest'})
                end
            else
                add(grid, {kind='water'})
            end
        end
    end
    
    -- perlin noise
    
    -- choose capital locations, then force 3x3 to be land
    -- split map into 4 'domains and randomly choose one for each player'
    local quad_pad = 2
    local quad_w = flr(grid_w / 2) - quad_pad
    local quad_h = flr(grid_h / 2) - quad_pad
    local quadrants = {
        {quad_pad+quad_w, quad_pad+quad_h},
        {quad_pad+quad_w, grid_h-quad_pad-quad_h},
        {grid_w-quad_pad-quad_w, quad_pad+quad_h},
        {grid_w-quad_pad-quad_w, grid_h-quad_pad-quad_h},
    }

    shuffle(quadrants)
    
    for i, player in ipairs(players) do
        local cap_x = flr(rnd(grid_w)) + quadrants[i][1]
        local cap_y = flr(rnd(grid_h)) + quadrants[i][2]
        
        -- insert player capital into map
        -- TODO generste a goofy name
        add(grid_at(cap_x, cap_y).buildings, {kind='city', level=1, tribe=player.tribe, capital=true})
    end
    
    
end

function _init()
    generate_map()
end

function _update()

end

function draw_map(offset_x, offset_y)
    for j=0,grid_h do
        for i=0,grid_w do
            -- determine color to use
            
            local x = offset_x-j*8+i*8
            local y = offset_y+j*4+i*4
            draw_tile(grid[j*grid_w+i+1], x, y)
        end
    end
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
    
    -- draw buildings on the tile
    for _, building in ipairs(tile.buildings) do
        draw_building(building, x, y)
    end
end

function draw_building(building, x, y)
    if building.kind == 'forest' then
    -- placeholder art
        circfill(x, y+4, 4, 7)
    elseif building.kind == 'city' then
        local c = 5
        if building.tribe == 'red' then
            c = 8
        elseif building.tribe == 'blue' then
            c = 12
        end
        rectfill(x-2, y-2, x+2, y+2, c)
    end
end

function _draw()
    cls(0)
    -- draw_tile({kind='grass'}, 64,64)
    draw_map(64, 10)
end