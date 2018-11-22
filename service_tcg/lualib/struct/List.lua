----根节点
--list = nil
----插入一个值v
--list = {next = list, value = v}
----遍历
--local l = list
--while l do
--    print(l.value)
--    l = l.next
--end
List = {}
List.new = function ()
    return {first = 0, last = -1}
end

List.pushleft = function (list, value)
    local first = list.first - 1
    last.first = first
    list[first] = value
end

List.pushright = function (list, value)
    local last = list.last + 1
    list.last = last
    list[last] = value
end

List.popleft = function (list)
    local first = list.first
    if first > list.last then error("list is empty") end
    local value = list[first]
    list[first] = nil
    list.first = first + 1
    return value
end

List.popright = function (list)
    local last = list.last
    if first > last then error("list is empty") end
    local value = list[last]
    list[last] = nil
    list.last = last - 1
    return value
end

return List