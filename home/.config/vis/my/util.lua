local M = {}

-- 这里集中放跨模块重复的小工具函数。
-- 只收“无状态、无 vis 依赖”的函数，避免 util 反过来绑死具体功能模块。

-- 所有传给 shell 的动态字符串都必须单引号转义，避免路径里的空格/引号破坏命令。
function M.shquote(value)
  value = tostring(value or "")
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

-- vis :command 参数使用双引号；这里处理路径中的反斜杠和双引号。
function M.visquote(value)
  value = tostring(value or "")
  return "\"" .. value:gsub("\\", "\\\\"):gsub("\"", "\\\"") .. "\""
end

-- Lua 5.1/5.2 对 os.execute 返回值不完全一致，所以同时兼容 true/0/code。
function M.os_ok(command)
  local ok, _, code = os.execute(command)
  return ok == true or ok == 0 or code == 0
end

function M.command_exists(command)
  return M.os_ok("command -v " .. M.shquote(command) .. " >/dev/null 2>&1")
end

function M.basename(path)
  return tostring(path or ""):match("[^/]+$") or ""
end

function M.dirname(path)
  path = tostring(path or "")
  return path:match("^(.+)/[^/]*$") or "."
end

function M.expand_home(path)
  path = tostring(path or "")
  if path:sub(1, 2) == "~/" then
    return (os.getenv("HOME") or ".") .. path:sub(2)
  end
  return path
end

function M.escape_pattern(value)
  return tostring(value or ""):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

function M.trim(value)
  return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function M.home_shorten(path)
  path = tostring(path or "")
  local home = os.getenv("HOME")
  if not home or home == "" then return path end
  return path:gsub("^" .. M.escape_pattern(home), "~")
end

function M.exists(path)
  return path and path ~= "" and M.os_ok("test -e " .. M.shquote(path))
end

function M.is_dir(path)
  return path and path ~= "" and M.os_ok("test -d " .. M.shquote(path))
end

function M.is_file(path)
  return path and path ~= "" and M.os_ok("test -f " .. M.shquote(path))
end

function M.mkdir_p(path)
  if not path or path == "" then return false end
  return M.os_ok("mkdir -p " .. M.shquote(path))
end

-- os.tmpname 在少数环境可能失败；保留 fallback，给 fzf 临时输入/输出文件使用。
function M.temp_path(prefix)
  local path = os.tmpname()
  if path and path ~= "" then return path end
  return "/tmp/" .. (prefix or "vis") .. "-" .. tostring(os.time()) .. "-" .. tostring(math.random(1000000))
end

-- fzf 结果只需要第一行；remove=true 时顺手清理临时输出文件。
function M.read_first_line(path, remove)
  local file = io.open(path, "r")
  if not file then return nil end
  local line = file:read("*l")
  file:close()
  if remove then os.remove(path) end
  if not line or line == "" then return nil end
  return line
end

function M.write_all(path, data)
  local file = io.open(path, "wb")
  if not file then return false end
  file:write(data or "")
  file:close()
  return true
end

function M.write_lines(path, lines)
  local file = io.open(path, "w")
  if not file then return false end
  for _, line in ipairs(lines or {}) do
    file:write(line, "\n")
  end
  file:close()
  return true
end

function M.read_lines(path, remove)
  local lines = {}
  local file = io.open(path, "r")
  if file then
    for line in file:lines() do table.insert(lines, line) end
    file:close()
  end
  if remove then os.remove(path) end
  return lines
end

return M
