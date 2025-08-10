-- ext/Server/BotChatter/Util.lua
-- Code by: JMDigital (https://github.com/JenkinsTR)
local U = {}

function U.strip_tags(name)
  if not name then return "" end
  -- Remove leading bracketed tags: [AU], (AU), {AU}
  return (name:gsub("^%b[]", ""):gsub("^%b()", ""):gsub("^%b{}", "")):gsub("^%s+", "")
end

function U.simple_hash(s, seed)
  local h = seed or 1337
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end

function U.merge_arrays(a, b, c)
  local t = {}
  if a then for i=1,#a do t[#t+1] = a[i] end end
  if b then for i=1,#b do t[#t+1] = b[i] end end
  if c then for i=1,#c do t[#t+1] = c[i] end end
  return t
end

return U
