pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

#include menu.p8

main_menu = menu_new({
    {label='play', fn=function()end},
    {label='how to play', fn=function()end},
    {label='quit', fn=function()end},
})
main_menu.visible = true

function _init()
    
end


function update_main_menu()
    if btnp(2) then
        main_menu:up()
    elseif btnp(3) then
        main_menu:down()
    elseif btnp(4) then
        
    elseif btnp(5) then
        main_menu:cur().fn()
    end
end

function _update60()
    if main_menu.visible then
        update_main_menu()
    end
end

function draw_main_menu()
    for i, item in ipairs(main_menu.items) do
        local c = 6
        if main_menu:index() == i then
            c = 7
        end
        print(item.label, 64-#item.label*2, 20 + i*8, c)
    end
end

function _draw()
    cls(0)
    if main_menu.visible then
        draw_main_menu()
    end
end