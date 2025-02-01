pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

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

function clone_table(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = clone_table(v)
    end
    return copy
end
