require("vis")
local vis = vis

local history = require("my.history")
local project = require("my.project")

local mode_names = {
  [vis.modes.INSERT] = "INSERT",
  [vis.modes.NORMAL] = "NORMAL",
  [vis.modes.OPERATOR_PENDING] = "NORMAL",
  [vis.modes.REPLACE] = "REPLACE",
  [vis.modes.VISUAL] = "VISUAL",
  [vis.modes.VISUAL_LINE] = "V-LINE",
}

local mode_styles

local function define_styles()
  if mode_styles then return mode_styles end

  mode_styles = {
    normal = assert(vis.ui:style_push("fore:#222222,back:#d8d8d8,bold")),
    insert = assert(vis.ui:style_push("fore:#222222,back:#b8e6b8,bold")),
    visual = assert(vis.ui:style_push("fore:#222222,back:#efb1a6,bold")),
    replace = assert(vis.ui:style_push("fore:#222222,back:#f0df9a,bold")),
  }

  return mode_styles
end

local function mode_style(styles)
  if vis.mode == vis.modes.INSERT then return styles.insert end
  if vis.mode == vis.modes.REPLACE then return styles.replace end
  if vis.mode == vis.modes.VISUAL or vis.mode == vis.modes.VISUAL_LINE then return styles.visual end
  return styles.normal
end

local function percent(win)
  local size = win.file.size or 0
  if size <= 0 then return "0%" end

  local pos = win.selection and win.selection.pos or 0
  return tostring(math.floor((pos * 100 / size) + 0.5)) .. "%"
end

local function history_label(path, current, current_modified)
  local label = project.relative(path)
  if label == "-" then label = tostring(path or "-") end

  if path == current then
    return ">" .. label .. (current_modified and "+" or "")
  end

  return label
end

local function history_text(current, current_modified)
  local files = history.files(20)

  if #files == 0 and current then
    files = { current }
  end

  local labels = {}
  for _, path in ipairs(files) do
    table.insert(labels, history_label(path, current, current_modified))
  end

  if #labels == 0 then return ">-" end
  return table.concat(labels, "  ")
end

local function draw(win)
  local mode_label = " " .. (mode_names[vis.mode] or "?") .. " "
  local current = project.absolute(win.file.path or win.file.name)
  local modified = win.file.modified
  local syntax = win.syntax or "text"
  local line = win.selection and win.selection.line or 1
  local col = win.selection and win.selection.col or 1

  win:status(
    mode_label .. " " .. project.home_shorten(project.root) .. " | " .. history_text(current, modified),
    " " .. table.concat({ syntax, tostring(line) .. "," .. tostring(col), percent(win) }, "  ") .. " "
  )

  if win == vis.win then
    local styles = define_styles()
    for x = 0, #mode_label - 1 do
      win:style_pos(mode_style(styles), x, win.height - 1)
    end
  end

  return true
end

vis.events.subscribe(vis.events.WIN_STATUS, draw)
