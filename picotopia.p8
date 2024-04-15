pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

GRID_HEIGHT = 16
GRID_WIDTH = 16

CELLS = 8

cam_x = 0
cam_y = 0

function _init()
    
end

function _update()

    x = 0
    y = 0
    if btn(0) then
        x = -1
    elseif btn(1) then
        x = 1
    elseif btn(2) then
        y = -1
    elseif btn(3) then
        y = 1
    end

    cam_x = cam_x + x
    cam_y = cam_y + y

    camera(cam_x, cam_y)

end

function _draw()
    cls()
    -- draw each cell
    for cell_y=0,CELLS-1 do
        for cell_x=0,CELLS-1 do
            color = (cell_x + cell_y) % 5 + 1
            cell_startx = (cell_x * GRID_HEIGHT) + (-1 * cell_y * GRID_HEIGHT)
            cell_starty = (cell_x * GRID_HEIGHT/2) + (cell_y * GRID_HEIGHT/2)
            -- circfill(cell_startx, cell_starty, 1, 2)
            for i=0,GRID_HEIGHT/2-1 do
                starty = cell_starty + 1 + i
                line(cell_startx - 2*i, starty, cell_startx + 2*i, starty, color)
            end
            for i=0,GRID_HEIGHT/2-1 do
                starty = cell_starty + GRID_HEIGHT/2 + i
                line(cell_startx - 2*(GRID_HEIGHT/2-i), starty, cell_startx + 2*(GRID_HEIGHT/2-i), starty, color)
            end
        end
    end
    -- draw grid outline
    for i=0,CELLS do
        startx = -1 * i * GRID_HEIGHT
        starty = i*GRID_HEIGHT/2
        line(startx, starty, startx+GRID_WIDTH*CELLS, starty+GRID_HEIGHT/2*CELLS, 6)
        startx = i * GRID_HEIGHT
        starty = i*GRID_HEIGHT/2
        line(startx, starty, startx-GRID_WIDTH*CELLS, starty+GRID_HEIGHT/2*CELLS, 6)
    end
end

function randint(min, max)
    return flr(rnd(max - min + 1)) + min
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
