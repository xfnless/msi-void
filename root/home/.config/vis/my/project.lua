require("vis")
local vis = vis

local util = require("my.util")

local M = {}

M.root = (os.getenv("PWD") or "."):gsub("/+$", "")
if M.root == "" then M.root = "/" end

local ignored_dirs = {
  ".git",
  "node_modules",
  "vendor",
  "dist",
  "build",
  "target",
}

function M.shquote(value)
  return util.shquote(value)
end

function M.visquote(value)
  return util.visquote(value)
end

function M.home_shorten(path)
  return util.home_shorten(path)
end

function M.absolute(path)
  path = tostring(path or "")
  if path == "" then return nil end
  if path:sub(1, 1) == "/" then return path end
  return M.root .. "/" .. path
end

function M.relative(path)
  if not path or path == "" then return "-" end

  local absolute = M.absolute(path)
  if not absolute then return "-" end

  local prefix = M.root .. "/"
  if absolute:sub(1, #prefix) == prefix then
    return absolute:sub(#prefix + 1)
  end
  if absolute == M.root then return "." end

  return M.home_shorten(absolute)
end

function M.in_root(path)
  local absolute = M.absolute(path)
  if not absolute then return false end
  return absolute == M.root or absolute:sub(1, #(M.root .. "/")) == M.root .. "/"
end

function M.command_exists(command)
  return util.command_exists(command)
end

function M.is_file(path)
  local absolute = M.absolute(path)
  return absolute and util.is_file(absolute)
end

function M.is_dir(path)
  local absolute = M.absolute(path)
  return absolute and util.is_dir(absolute)
end

function M.basename(path)
  return util.basename(path)
end

function M.fd_exclude_args()
  local parts = {}
  for _, dir in ipairs(ignored_dirs) do
    table.insert(parts, "--exclude " .. M.shquote(dir))
  end
  return table.concat(parts, " ")
end

function M.find_files(limit)
  limit = limit or 1000

  local files = {}
  local command = "cd " .. M.shquote(M.root)
    .. " && fd --type f --hidden --follow " .. M.fd_exclude_args() .. " . 2>/dev/null"
  local pipe = io.popen(command, "r")
  if not pipe then return files end

  for line in pipe:lines() do
    local path = line:gsub("^%./", "")
    if path ~= "" then
      table.insert(files, path)
      if #files >= limit then break end
    end
  end
  pipe:close()

  table.sort(files)
  return files
end

local function jump(line, col)
  if line and vis.win and vis.win.selection then
    vis.win.selection:to(math.max(1, tonumber(line) or 1), math.max(1, tonumber(col) or 1))
  end
end

local function redraw()
  pcall(function() vis:redraw() end)
end

function M.write_current()
  local win = vis.win
  if not win or not win.file then return false end
  if not win.file.path or win.file.path == "" then
    vis:info("write: current file has no path")
    return false
  end

  vis:command("w")
  redraw()
  return not win.file.modified
end

function M.save_current()
  M.write_current()
  return true
end

function M.edit(path, line, col)
  local absolute = M.absolute(path)
  if not absolute then return false end

  vis:command("e " .. M.visquote(absolute))

  local win = vis.win
  local opened = win and win.file and win.file.path == absolute
  if opened then
    jump(line, col)
  end

  return opened
end

function M.open(path, line, col)
  return M.edit(path, line, col)
end

return M
