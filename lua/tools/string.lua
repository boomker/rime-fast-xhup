function string.split(str, sp, sp1)
    sp = type(sp) == "string" and sp or " "
    if #sp == 0 then
        sp = "([%z\1-\127\194-\244][\128-\191]*)"
    elseif #sp == 1 then
        sp = "[^" .. (sp == "%" and "%%" or sp) .. "]*"
    else
        sp1 = sp1 or "^"
        str = str:gsub(sp, sp1)
        sp = "[^" .. sp1 .. "]*"
    end

    local tab = {}
    for v in str:gmatch(sp) do table.insert(tab, v) end
    return tab
end

function utf8.gsub(str, si, ei)
    local function index(ustr, i)
        return i >= 0 and (ustr:utf8_offset(i) or ustr:len() + 1) or
                   (ustr:utf8_offset(i) or 1)
    end

    local u_si = index(str, si)
    ei = ei or str:utf8_len()
    ei = ei >= 0 and ei + 1 or ei
    local u_ei = index(str, ei) - 1
    return str:gsub(u_si, u_ei)
end

function utf8.csub(s, i, j)
    i = i or 1
    j = j or -1

    if i < 1 or j < 1 then
        local n = utf8.len(s)
        if not n then return nil end
        if i < 0 then i = n + 1 + i end
        if j < 0 then j = n + 1 + j end
        if i < 0 then
            i = 1
        elseif i > n then
            i = n
        end
        if j < 0 then
            j = 1
        elseif j > n then
            j = n
        end
    end

    if j < i then return "" end

    i = utf8.offset(s, i)
    j = utf8.offset(s, j + 1)

    if i and j then
        return s:sub(i, j - 1)
    elseif i then
        return s:sub(i)
    else
        return ""
    end
end

function utf8.chars(word)
    local f, s, i = utf8.codes(word)
    return function()
        local j, value = s and i and f(s, i) or nil, nil
        if j and value then
            return j, utf8.char(value)
        else
            return nil
        end
    end
end

string.split = string.split
string.utf8_len = utf8.len
string.utf8_offset = utf8.offset
string.utf8_gsub = utf8.gsub
string.utf8_sub = utf8.csub
string.utf8_chars = utf8.chars
return true
