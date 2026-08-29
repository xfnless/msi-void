require("vis")
local vis = vis

local project = require("my.project")

local session_order = {}
local alternate_path = nil

local M = {}

local function ignored(path)
  return not path or path == "" or path:match("COMMIT_EDITMSG$") or path:match("git%-rebase%-todo$")
end

local function expand_path(path)
  path = tostring(path or "")
  if path == "" then return nil end
  if path:sub(1, 2) == "~/" then
    return (os.getenv("HOME") or ".") .. path:sub(2)
  end
  if path:sub(1, 1) == "/" then return path end
  return project.absolute(path)
end

local function append_once(list, path)
  if not path or path == "" then return end
  for _, item in ipairs(list) do
    if item == path then return end
  end
  table.insert(list, path)
end

local function current_path()
  local win = vis.win
  if not win or not win.file or not win.file.path then return nil end

  local path = expand_path(win.file.path)
  if ignored(path) or not project.is_file(path) then return nil end
  return path
end

local function remember_current()
  local path = current_path()
  if path then append_once(session_order, path) end
  return path
end

local function collect_files(source, limit)
  limit = limit or 50

  local files = {}
  local seen = {}
  for _, path in ipairs(source) do
    if not seen[path] and project.is_file(path) then
      seen[path] = true
      table.insert(files, path)
      if #files >= limit then break end
    end
  end
  return files
end

function M.absolute(path)
  return expand_path(path)
end

function M.current_path()
  return current_path()
end

function M.remember_current()
  return remember_current()
end

function M.files(limit)
  remember_current()
  return collect_files(session_order, limit)
end

function M.open(path, line, col)
  local previous = remember_current()
  local absolute = expand_path(path)
  if not absolute then return false end

  local ok = project.edit(absolute, line, col)
  if ok and project.is_file(absolute) then
    append_once(session_order, absolute)
    if previous and previous ~= absolute then
      alternate_path = previous
    end
  end

  return ok
end

function M.back()
  local current = remember_current()
  if not alternate_path or not project.is_file(alternate_path) then
    vis:info("history: no previous file")
    return true
  end

  local target = alternate_path
  local ok = project.edit(target)
  if ok then
    append_once(session_order, target)
    if current and current ~= target then
      alternate_path = current
    end
  end

  return true
end

vis.events.subscribe(vis.events.WIN_OPEN, function(win)
  if not win or not win.file or not win.file.path then return end
  local path = expand_path(win.file.path)
  if not ignored(path) and project.is_file(path) then
    append_once(session_order, path)
  end
end)

vis.events.subscribe(vis.events.WIN_CLOSE, function(win)
  if not win or not win.file or not win.file.path then return end
  local path = expand_path(win.file.path)
  if not ignored(path) and project.is_file(path) then
    append_once(session_order, path)
  end
end)

return M
