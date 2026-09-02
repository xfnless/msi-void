require("vis")
local vis = vis

local history = require("my.history")
local project = require("my.project")
local util = require("my.util")

local M = {}

local config = {
  root = ((os.getenv("HOME") or ".") .. "/notes"):gsub("/+$", ""),
}

local styles = {}

local function in_root(path)
  path = tostring(path or "")
  if path == "" then return false end
  return path == config.root or path:sub(1, #(config.root .. "/")) == config.root .. "/"
end

local function path_for_win(win)
  if not win or not win.file then return nil end
  local path = win.file.path or win.file.name
  if not path or path == "" then return nil end
  if path:sub(1, 1) == "/" then return path end
  return project.absolute(path)
end

local function current_path()
  return path_for_win(vis.win)
end

local function today()
  return os.date("%Y-%m-%d")
end

local function now_header()
  return os.date("# %Y-%m-%d %H:%M")
end

local function entry_path_for_date(date)
  local year, month = tostring(date or ""):match("^(%d%d%d%d)%-(%d%d)")
  if not year or not month then return config.root .. "/" .. tostring(date or "") .. ".md" end
  return config.root .. "/" .. year .. "/" .. month .. "/" .. tostring(date) .. ".md"
end

local function ensure_newline(text)
  text = tostring(text or "")
  if text == "" or text:sub(-1) == "\n" then return text end
  return text .. "\n"
end

local function visual_mode()
  return vis.mode == vis.modes.VISUAL or vis.mode == vis.modes.VISUAL_LINE
end

local function selected_text(win)
  if not visual_mode() then return nil end
  if not win or not win.file or not win.selection then return nil end

  local range = win.selection.range
  if not range or range.start == range.finish then return nil end

  local start = math.min(range.start, range.finish)
  local finish = math.max(range.start, range.finish)
  if finish <= start then return nil end

  return win.file:content(start, finish - start) or ""
end

local function append_to_file(path, content)
  local existing = ""
  local read = io.open(path, "r")
  if read then
    existing = read:read("*a") or ""
    read:close()
  end

  local row = 1
  if existing ~= "" then
    for _ in existing:gmatch("\n") do row = row + 1 end
    if existing:sub(-1) ~= "\n" then
      existing = existing .. "\n"
      row = row + 1
    end
    existing = existing .. "\n"
    row = row + 1
  end

  local file = io.open(path, "w")
  if not file then return false, nil end
  file:write(existing, content)
  file:close()
  return true, row
end

local function append_to_buffer(file, content)
  if not file then return false, nil end

  local existing = file:content(0, file.size) or ""
  local addition = content
  local row = 1
  if existing ~= "" then
    for _ in existing:gmatch("\n") do row = row + 1 end
    if existing:sub(-1) ~= "\n" then
      addition = "\n" .. addition
      row = row + 1
    end
    addition = "\n" .. addition
    row = row + 1
  end

  file:insert(file.size, addition)
  return true, row
end

local function build_entry(text)
  text = util.trim(text or "")
  if text == "" then
    return now_header() .. "\n\n\n"
  end
  return now_header() .. "\n\n" .. ensure_newline(text)
end

local preview_command

local function entry_heading(line)
  return tostring(line or ""):match("^# (%d%d%d%d%-%d%d%-%d%d %d%d:%d%d)%s*$")
end

local function collect_entries()
  local entries = {}
  if not util.is_dir(config.root) then return entries end

  local command = "cd " .. util.shquote(config.root) .. " && fd --type f --hidden --follow --extension md . 2>/dev/null"
  local pipe = io.popen(command, "r")
  if not pipe then return entries end

  for line in pipe:lines() do
    local rel = line:gsub("^%./", "")
    local path = config.root .. "/" .. rel
    local file = io.open(path, "r")
    if file then
      local row = 0
      local pending = nil
      for text in file:lines() do
        row = row + 1
        local stamp = entry_heading(text)
        if stamp then
          if pending then table.insert(entries, pending) end
          pending = { stamp = stamp, path = path, rel = rel, row = row, snippet = "", body = "" }
        elseif pending and pending.snippet == "" then
          local snippet = util.trim(text)
          if snippet ~= "" then pending.snippet = snippet end
          pending.body = util.trim(pending.body .. " " .. text)
        elseif pending then
          pending.body = util.trim(pending.body .. " " .. text)
        end
      end
      if pending then table.insert(entries, pending) end
      file:close()
    end
  end
  pipe:close()

  table.sort(entries, function(a, b)
    if a.stamp == b.stamp then
      if a.path == b.path then return a.row > b.row end
      return a.path > b.path
    end
    return a.stamp > b.stamp
  end)
  return entries
end

local function write_entry_rows(path, entries)
  local file = io.open(path, "w")
  if not file then return false end
  for _, entry in ipairs(entries) do
    local label = entry.stamp
    if entry.snippet and entry.snippet ~= "" then label = label .. "  " .. entry.snippet end
    local body = tostring(entry.body or ""):gsub("\t", " "):gsub("%s+", " ")
    file:write(label, "\t", entry.path, "\t", entry.row, "\t", body, "\n")
  end
  file:close()
  return true
end

local function fzf_entries(entries, prompt, extra_args)
  if #entries == 0 then return nil end
  if not project.command_exists("fzf") then
    vis:info("entry: fzf not found")
    return nil
  end

  local input = util.temp_path("vis-entry")
  if not write_entry_rows(input, entries) then
    vis:info("entry: failed to create fzf input")
    return nil
  end

  local out = util.temp_path("vis-entry")
  local preview = preview_command("{2}", "{3}")
  local command = "fzf --no-sort --prompt=" .. util.shquote(prompt)
    .. " --delimiter=" .. util.shquote("\t")
    .. " --with-nth=1 --preview " .. util.shquote(preview)
  if extra_args and extra_args ~= "" then command = command .. " " .. extra_args end
  command = "cd " .. util.shquote(config.root)
    .. " && ( " .. command .. " < " .. util.shquote(input)
    .. " > " .. util.shquote(out) .. " || true )"

  vis:command("! " .. command)
  pcall(function() vis:redraw() end)

  local lines = util.read_lines(out, true)
  os.remove(input)
  if #lines == 0 then return nil end
  return lines
end

local function fzf_choice_line(lines)
  lines = lines or {}
  for index = #lines, 1, -1 do
    if lines[index] ~= "" then return lines[index] end
  end
  return nil
end

local function parse_entry_choice(line)
  local _, path, row = tostring(line or ""):match("^([^\t]*)\t([^\t]+)\t(%d+)")
  if not path then return nil end
  return { path = path, row = tonumber(row) or 1 }
end

local function create_entry(text)
  local win = vis.win
  local selection = selected_text(win)
  if selection and selection ~= "" then text = selection end

  local path = entry_path_for_date(today())
  local dir = util.dirname(path)
  if not util.mkdir_p(dir) then
    vis:info("entry: failed to create directory: " .. dir)
    return true
  end

  local content = build_entry(text)
  local same_buffer = win and win.file and current_path() == path
  local ok, row
  if same_buffer then
    ok, row = append_to_buffer(win.file, content)
    if ok then project.write_current() end
  else
    ok, row = append_to_file(path, content)
  end
  if not ok then
    vis:info("entry: failed to write entry")
    return true
  end

  history.open(path, (row or 1) + 2, 1)
  return true
end

function preview_command(path_expr, line_expr)
  if project.command_exists("bat") then
    return "bat --style=numbers --color=always --theme=ansi --highlight-line " .. line_expr
      .. " --line-range " .. line_expr .. ":+80 -- " .. path_expr
  end
  return "sed -n " .. util.shquote(line_expr .. "," .. line_expr .. "p") .. " -- " .. path_expr
end

local function open_entry_list()
  local entries = collect_entries()
  if #entries == 0 then
    vis:info("entry: no entries")
    return true
  end

  local lines = fzf_entries(entries, "entry> ")
  if not lines then return true end

  local entry = parse_entry_choice(fzf_choice_line(lines))
  if entry then history.open(entry.path, entry.row, 1) end
  return true
end

local function search_entries(query)
  query = util.trim(query or "")
  if query == "" then
    vis:info("entry: empty query")
    return true
  end
  if not util.is_dir(config.root) then
    vis:info("entry: root not found: " .. config.root)
    return true
  end
  if not project.command_exists("rg") then
    vis:info("entry: rg not found")
    return true
  end
  if not project.command_exists("fzf") then
    vis:info("entry: fzf not found")
    return true
  end

  local input = util.temp_path("vis-entry")
  local out = util.temp_path("vis-entry")
  local rg = "cd " .. util.shquote(config.root)
    .. " && rg --fixed-strings --line-number --column --no-heading --color=never"
    .. " --field-match-separator " .. util.shquote("\t")
    .. " -- " .. util.shquote(query) .. " . 2>/dev/null"
    .. " > " .. util.shquote(input) .. " || true"
  os.execute(rg)

  if not util.read_first_line(input, false) then
    os.remove(input)
    os.remove(out)
    vis:info("entry: no results")
    return true
  end

  local preview = preview_command("{1}", "{2}")
  local command = "cd " .. util.shquote(config.root)
    .. " && ( fzf --prompt=" .. util.shquote("search> ")
    .. " --delimiter=" .. util.shquote("\t")
    .. " --with-nth=1,2,4.. --preview " .. util.shquote(preview)
    .. " < " .. util.shquote(input) .. " > " .. util.shquote(out) .. " || true )"
  vis:command("! " .. command)
  pcall(function() vis:redraw() end)

  local choice = util.read_first_line(out, true)
  os.remove(input)
  if not choice then return true end

  local path, row, col = choice:match("^([^\t]+)\t(%d+)\t(%d+)\t")
  if path and row then
    path = path:gsub("^%./", "")
    history.open(config.root .. "/" .. path, tonumber(row), tonumber(col) or 1)
  end
  return true
end

local function token_under_cursor()
  local win = vis.win
  if not win or not win.file or not win.selection then return nil end

  local line = win.file.lines[win.selection.line] or ""
  local pos = win.selection.pos or 0
  local before = win.file:content(0, pos) or ""
  local line_start = 0
  for newline_pos in before:gmatch("()\n") do
    line_start = newline_pos
  end
  local col = pos - line_start + 1

  for first, query in line:gmatch("()%[%[([^%]\n]+)%]%]") do
    local raw = "[[" .. query .. "]]"
    local last = first + #raw - 1
    if col >= first and col <= last + 1 then
      return query
    end
  end

  return nil
end

local function search_token()
  local path = current_path()
  if not path or not in_root(path) then return false end

  local query = token_under_cursor()
  if not query then return false end
  search_entries(query)
  return true
end

local function define_styles(win)
  if styles[win] then return styles[win] end
  local style = win.STYLE_LEXER_MAX - 10
  win:style_define(style, "fore:#7683a3")
  styles[win] = style
  return style
end

local function highlight_tokens(win)
  if not win or not win.file or win.syntax ~= "markdown" then return end

  local path = path_for_win(win)
  if not path or not in_root(path) then return end

  local content = win.file:content(0, win.file.size) or ""
  local style = define_styles(win)
  for first, raw in content:gmatch("()%[%[([^%]\n]+)%]%]") do
    win:style(style, first - 1, first + #raw + 3, true)
  end
end

function M.setup(options)
  options = options or {}
  if options.root and options.root ~= "" then
    config.root = util.expand_home(tostring(options.root)):gsub("/+$", "")
  end

  vis.events.subscribe(vis.events.WIN_HIGHLIGHT, highlight_tokens)
  vis.events.subscribe(vis.events.WIN_CLOSE, function(win)
    styles[win] = nil
  end)
end

function M.in_root()
  local path = current_path()
  return path and in_root(path) or false
end

function M.open_entries()
  return open_entry_list()
end

function M.new_entry()
  return create_entry("")
end

function M.search_token()
  return search_token()
end

return M
