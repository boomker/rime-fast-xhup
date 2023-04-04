
---@diagnostic disable: undefined-global


local function sub(s, i, j)
    i = i or 1
    j = j or -1

    if i < 1 or j < 1 then
        local n = utf8.len(s)
        if not n then
            return nil
        end
        if i < 0 then
            if i < 0 then
                i = n + 1 + i
            end
            if j < 0 then
                j = n + 1 + j
            end
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

        if j < i then
            return ""
        end

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
end

return { utf8Sub = sub }
