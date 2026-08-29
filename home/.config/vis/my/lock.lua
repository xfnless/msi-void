require("vis")
local vis = vis

local util = require("my.util")

local state_home = os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or ".") .. "/.local/state")
local root = state_home .. "/vis/locks"
local held = {}
local pid

local function hash(path)
  local h = 5381
  for i = 1, #path do
    h = (h * 33 + path:byte(i)) % 4294967296
  end
  return string.format("%08x", h)
end

local function current_pid()
  if pid then return pid end

  local pipe = io.popen("sh -c 'echo $PPID'", "r")
  if pipe then
    pid = pipe:read("*l")
    pipe:close()
  end
  pid = pid or tostring(os.time())
  return pid
end

local function alive(value)
  local n = tonumber(value)
  return n and util.os_ok("kill -0 " .. n .. " 2>/dev/null")
end

local function read_pid(dir)
  local file = io.open(dir .. "/pid", "r")
  if not file then return nil end

  local value = file:read("*l")
  file:close()
  return value
end

local function lock_dir(path)
  return root .. "/" .. hash(path) .. ".lock"
end

local function take(path)
  util.mkdir_p(root)

  local dir = lock_dir(path)
  if util.os_ok("mkdir " .. util.shquote(dir) .. " 2>/dev/null") then
    util.write_all(dir .. "/pid", current_pid() .. "\n")
    held[path] = dir
    return
  end

  local owner = read_pid(dir)
  if not alive(owner) then
    os.execute("rm -rf " .. util.shquote(dir))
    if util.os_ok("mkdir " .. util.shquote(dir) .. " 2>/dev/null") then
      util.write_all(dir .. "/pid", current_pid() .. "\n")
      held[path] = dir
    end
    return
  end

  if owner ~= current_pid() then
    vis:message("already open in another terminal\n\n" .. path .. "\npid: " .. tostring(owner))
  end
end

local function release(path)
  local dir = held[path]
  if not dir then return end

  os.execute("rm -rf " .. util.shquote(dir))
  held[path] = nil
end

vis.events.subscribe(vis.events.WIN_OPEN, function(win)
  local path = win and win.file and win.file.path
  if path and not held[path] then take(path) end
end)

vis.events.subscribe(vis.events.FILE_CLOSE, function(file)
  if file and file.path then release(file.path) end
end)

vis.events.subscribe(vis.events.QUIT, function()
  for path in pairs(held) do release(path) end
end)
