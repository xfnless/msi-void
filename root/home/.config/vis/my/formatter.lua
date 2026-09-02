require("vis")
local vis = vis

local util = require("my.util")

local prettier_syntax = {
  css = true,
  html = true,
  javascript = true,
  json = true,
  jsx = true,
  markdown = true,
  svelte = true,
  tsx = true,
  typescript = true,
  vue = true,
  yaml = true,
}

local function with_path(win, option)
  local path = win.file and win.file.path
  if not path or path == "" then return "" end
  return option .. util.shquote(path)
end

-- 返回 nil 表示当前语法没有配置 formatter；保存逻辑会继续普通保存。
local function default_command(win)
  local syntax = win.syntax or ""

  if prettier_syntax[syntax] then
    return "prettier" .. with_path(win, " --stdin-filepath ")
  end
  if syntax == "lua" then return "stylua -" end
  if syntax == "bash" or syntax == "sh" then return "shfmt" .. with_path(win, " --filename ") .. " -" end
  if syntax == "python" then return "ruff format" .. with_path(win, " --stdin-filename ") .. " -" end

  return nil
end

local function restore_position(win, line, col)
  if not win or not win.selection then return end
  win.selection:to(math.min(line, math.max(1, #win.file.lines)), math.max(1, col))
end

local M = {}

-- 返回值给“=”使用：true 表示可以继续保存，false 表示 formatter 失败，应该中止保存。
function M.format()
  local win = vis.win
  if not win or not win.file then return true end

  local command = default_command(win)
  if not command then
    vis:info("fmt: no formatter for syntax " .. tostring(win.syntax or "text"))
    return true
  end

  local file = win.file
  local before = file:content(0, file.size)
  local line = win.selection and win.selection.line or 1
  local col = win.selection and win.selection.col or 1
  local status, out, err = vis:pipe(file, { start = 0, finish = file.size }, command)

  if status ~= 0 then
    local msg = (err and err ~= "") and err or ("exit " .. tostring(status))
    vis:message("fmt failed:\n" .. msg:gsub("\n$", ""))
    return false
  end

  out = out or ""
  if out ~= before then
    file:delete(0, file.size)
    file:insert(0, out)
    restore_position(win, line, col)
  end

  vis:info("fmt: " .. command)
  return true
end

return M
