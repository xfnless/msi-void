require("vis")
local vis = vis

local history = require("my.history")
local project = require("my.project")
local util = require("my.util")

local function fzf_available()
  if project.command_exists("fzf") then return true end
  vis:info("nav: fzf not found")
  return false
end

local function redraw()
  pcall(function() vis:redraw() end)
end

local function preview_command(file_expr, line_expr)
  local file = file_expr or "{}"
  if project.command_exists("bat") then
    local base = "bat --style=numbers --color=always --theme=ansi"
    if line_expr then
      return base .. " --highlight-line " .. line_expr .. " --line-range " .. line_expr .. ":+80 -- " .. file
    end
    return base .. " --line-range :200 -- " .. file
  end

  if line_expr then
    return "sed -n " .. project.shquote(line_expr .. "," .. line_expr .. "p") .. " -- " .. file
  end
  return "sed -n '1,200p' -- " .. file
end

local function run_fzf(command)
  if not fzf_available() then return nil end

  local out = util.temp_path("vis-fzf")
  local full = "cd " .. project.shquote(project.root)
    .. " && ( " .. command .. " > " .. project.shquote(out) .. " || true )"

  vis:command("! " .. full)
  redraw()
  return util.read_first_line(out, true)
end

local function fzf_from_command(input_command, fzf_args)
  return run_fzf(input_command .. " | fzf " .. fzf_args)
end

local function fzf_from_file(input_path, fzf_args)
  local choice = run_fzf("fzf " .. fzf_args .. " < " .. project.shquote(input_path))
  os.remove(input_path)
  return choice
end

local function open_path(path, line, col)
  if not path or path == "" then return true end
  history.open(path, line, col)
  return true
end

local function line_and_byte_col()
  local win = vis.win
  if not win or not win.file or not win.selection then return nil, nil end

  local line = win.file.lines[win.selection.line] or ""
  local pos = win.selection.pos or 0
  local before = win.file:content(0, pos) or ""
  local line_start = 0
  for newline_pos in before:gmatch("()\n") do
    line_start = newline_pos
  end

  return line, pos - line_start + 1
end

local function word_under_cursor()
  local line, col = line_and_byte_col()
  if not line then return "" end

  for first, word in line:gmatch("()([%a_][%w_%-]*)") do
    local last = first + #word - 1
    if col >= first and col <= last + 1 then return word end
  end

  return ""
end

local function selected_text_for_search()
  if vis.mode ~= vis.modes.VISUAL and vis.mode ~= vis.modes.VISUAL_LINE then return nil end

  local win = vis.win
  if not win or not win.file or not win.selection then return nil end
  local range = win.selection.range
  if not range or range.start == range.finish then return nil end

  local start = math.min(range.start, range.finish)
  local finish = math.max(range.start, range.finish)
  local text = win.file:content(start, finish - start) or ""
  text = util.trim(text:gsub("%s+", " "))
  if text == "" then return nil end
  return text
end

local function url_under_cursor()
  local line, col = line_and_byte_col()
  if not line then return nil end

  for first, url in line:gmatch([[()(https?://[^%s%"'`<>%)%]}]+)]]) do
    url = url:gsub("[%.%,%;:]+$", "")
    local last = first + #url - 1
    if col >= first and col <= last + 1 then return url end
  end

  return nil
end

local function find_command()
  return "fd --type f --hidden --follow " .. project.fd_exclude_args() .. " . 2>/dev/null"
end

local function project_file()
  local choice = fzf_from_command(
    find_command(),
    "--prompt='file> ' --preview " .. project.shquote(preview_command("{}"))
  )
  return open_path(choice)
end

local function display_path(path)
  if project.in_root(path) then return project.relative(path) end
  return project.home_shorten(path)
end

local function history_file()
  local rows = {}
  local seen = {}

  for _, path in ipairs(history.files(200)) do
    local label = display_path(path)
    if label ~= "-" and not seen[path] then
      seen[path] = true
      table.insert(rows, label .. "\t" .. path)
    end
  end

  if #rows == 0 then
    vis:info("history: no visited file")
    return true
  end

  local input = util.temp_path("vis-history")
  if not util.write_lines(input, rows) then
    vis:info("history: failed to create fzf input")
    return true
  end

  local choice = fzf_from_file(
    input,
    "--prompt='history> ' --delimiter=" .. project.shquote("\t")
      .. " --with-nth=1 --preview " .. project.shquote(preview_command("{2}"))
  )
  if not choice then return true end

  local path = choice:match("\t(.+)$") or choice
  return open_path(path)
end

local function grep_project(initial_query, word_regexp, fixed_strings)
  if not project.command_exists("rg") then
    vis:info("grep: rg not found")
    return true
  end
  if not fzf_available() then return true end

  local rg_args = ""
  if word_regexp then rg_args = rg_args .. " --word-regexp" end
  if fixed_strings then rg_args = rg_args .. " --fixed-strings" end

  local field_sep = project.shquote("\t")
  local reload = "rg --line-number --column --no-heading --color=never --smart-case"
    .. " --field-match-separator " .. field_sep .. rg_args .. " -- {q} . || true"
  local preview = preview_command("{1}", "{2}")
  local query = initial_query or ""
  local command = "fzf --disabled --prompt='grep> '"
    .. " --query " .. project.shquote(query)
    .. " --bind " .. project.shquote("start:reload:" .. reload)
    .. " --bind " .. project.shquote("change:reload:" .. reload)
    .. " --delimiter " .. field_sep
    .. " --preview " .. project.shquote(preview)

  local choice = run_fzf(command)
  if not choice then return true end

  local path, row, col = choice:match("^([^\t]+)\t(%d+)\t(%d+)\t")
  if path and row then
    path = path:gsub("^%./", "")
    history.open(path, tonumber(row), tonumber(col) or 1)
  end
  return true
end

local function grep_history()
  if not project.command_exists("rg") then
    vis:info("grep: rg not found")
    return true
  end
  if not fzf_available() then return true end

  local files = {}
  local seen = {}
  for _, path in ipairs(history.files(500)) do
    if not seen[path] and project.is_file(path) then
      seen[path] = true
      table.insert(files, path)
    end
  end
  if #files == 0 then
    vis:info("history grep: no visited file")
    return true
  end

  local input = util.temp_path("vis-history")
  if not util.write_lines(input, files) then
    vis:info("history grep: failed to create file list")
    return true
  end

  local field_sep = project.shquote("\t")
  local reload = "rg --line-number --column --no-heading --color=never --smart-case"
    .. " --field-match-separator " .. field_sep
    .. " --files-from " .. project.shquote(input)
    .. " -- {q} || true"
  local preview = preview_command("{1}", "{2}")
  local command = "fzf --disabled --prompt='history grep> '"
    .. " --bind " .. project.shquote("start:reload:" .. reload)
    .. " --bind " .. project.shquote("change:reload:" .. reload)
    .. " --delimiter " .. field_sep
    .. " --preview " .. project.shquote(preview)

  local choice = run_fzf(command)
  os.remove(input)
  if not choice then return true end

  local path, row, col = choice:match("^([^\t]+)\t(%d+)\t(%d+)\t")
  if path and row then
    history.open(path, tonumber(row), tonumber(col) or 1)
  end
  return true
end

local function url_decode(s)
  return tostring(s or ""):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

local function markdown_link_target(line, col)
  for first, whole, target in line:gmatch("()(%[[^%]\n]*%]%(([^%)\n]+)%))") do
    local last = first + #whole - 1
    if col >= first and col <= last + 1 then return target end
  end
  return nil
end

local function file_uri_target(line, col)
  for first, uri in line:gmatch("()(file://[^%s%)%]]+)") do
    uri = uri:gsub("[%.%,%;:]+$", "")
    local last = first + #uri - 1
    if col >= first and col <= last + 1 then return uri end
  end
  return nil
end

local function plain_path_target(line, col)
  if not line or not col then return nil end

  local left = col
  while left > 1 do
    local char = line:sub(left - 1, left - 1)
    if char:match("[%s%\"%'`<>()%[%]{}]") then break end
    left = left - 1
  end

  local right = col
  while right <= #line do
    local char = line:sub(right, right)
    if char:match("[%s%\"%'`<>()%[%]{}]") then break end
    right = right + 1
  end

  local token = line:sub(left, right - 1):gsub("[%.%,%;:]+$", "")
  if token == "" then return nil end
  if token:match("^https?://") or token:match("^file://") then return token end
  if token:match("^~/") or token:match("^/") or token:match("^%.%.?/") or token:match("[%w_%-]+%.[%w_%-]+") then
    return token
  end

  return nil
end

local function target_under_cursor()
  local line, col = line_and_byte_col()
  if not line then return nil end
  return markdown_link_target(line, col) or file_uri_target(line, col) or url_under_cursor() or plain_path_target(line, col)
end

local function normalize_target(target)
  if not target or target == "" then return nil end
  target = target:gsub("^<", ""):gsub(">$", "")

  if target:match("^https?://") then return target, true end

  if target:match("^file://") then
    target = url_decode(target:gsub("^file://", ""))
  else
    target = url_decode(target)
  end

  if target:sub(1, 2) == "~/" then
    target = (os.getenv("HOME") or "") .. target:sub(2)
  elseif target:sub(1, 1) ~= "/" then
    local current = vis.win and vis.win.file and vis.win.file.path
    local base = project.root
    if current and current ~= "" then
      base = current:match("^(.+)/[^/]*$") or base
    end
    target = base .. "/" .. target
  end

  return target, false
end

local text_extensions = {
  c = true,
  css = true,
  go = true,
  h = true,
  html = true,
  js = true,
  json = true,
  jsx = true,
  lua = true,
  md = true,
  php = true,
  py = true,
  rb = true,
  rs = true,
  sh = true,
  sql = true,
  ts = true,
  tsx = true,
  txt = true,
  vue = true,
  xml = true,
  yaml = true,
  yml = true,
}

local function text_by_extension(path)
  local ext = tostring(path or ""):match("%.([%w_%-]+)$")
  return ext and text_extensions[ext:lower()] or false
end

local function text_file(path)
  if text_by_extension(path) then return true end
  if not project.command_exists("file") then return false end

  local pipe = io.popen("file --brief --mime-type -- " .. project.shquote(path), "r")
  if not pipe then return false end
  local mime = pipe:read("*l") or ""
  pipe:close()

  return mime:match("^text/")
    or mime == "inode/x-empty"
    or mime == "application/json"
    or mime == "application/xml"
    or mime == "application/javascript"
    or mime == "application/x-sh"
end

local function open_target()
  local target = target_under_cursor()
  if not target then
    vis:info("gf: no file under cursor")
    return true
  end

  local path, external = normalize_target(target)
  if not path then
    vis:info("gf: invalid target")
    return true
  end

  if external then
    os.execute("xdg-open " .. project.shquote(path) .. " >/dev/null 2>&1 &")
    return true
  end

  if not project.is_file(path) and not project.is_dir(path) then
    vis:info("gf: not found: " .. path)
    return true
  end

  if project.is_file(path) and text_file(path) then
    history.open(path)
    return true
  end

  os.execute("xdg-open " .. project.shquote(path) .. " >/dev/null 2>&1 &")
  return true
end

local M = {}

function M.file()
  return project_file()
end

function M.grep()
  return grep_project()
end

function M.grep_history()
  return grep_history()
end

function M.grep_word()
  local selection = selected_text_for_search()
  if selection then
    return grep_project(selection, false, true)
  end

  local query = word_under_cursor()
  if query == "" then
    vis:info("grep: no word under cursor")
    return true
  end
  return grep_project(query, true, false)
end

function M.history()
  return history_file()
end

function M.back()
  return history.back()
end

function M.gf()
  return open_target()
end

function M.url()
  local url = url_under_cursor()
  if not url then
    vis:info("gx: no url under cursor")
    return true
  end

  os.execute("xdg-open " .. project.shquote(url) .. " >/dev/null 2>&1 &")
  return true
end

return M
