require("vis")
local vis = vis

local history = require("my.history")
local util = require("my.util")

local history_limit = 50
local byte_limit = 512 * 1024

local function prefix(win)
	local line = win.file.lines[win.selection.line] or ""
	local before = line:sub(1, math.max((win.selection.col or 1) - 1, 0))
	return before:match("([%a_][%w_%-]*)$") or before:match("([%w_%-]+)$") or ""
end

local function read(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local data = file:read(byte_limit + 1)
	file:close()
	if data and #data <= byte_limit then return data end
end

local function add_words(out, seen, text, head)
	for word in tostring(text or ""):gmatch("[%a_][%w_%-]+") do
		if #word > #head and word:sub(1, #head) == head and not seen[word] then
			seen[word] = true
			table.insert(out, word)
		end
	end
end

local function choose(items)
	table.sort(items)
	if #items == 0 then return nil end
	if #items == 1 or not util.command_exists("vis-menu") then return items[1] end

	local status, out = vis:pipe(table.concat(items, "\n") .. "\n", "vis-menu -i -b -p word:")
	if status == 0 and out and out ~= "" then
		return out:gsub("\n.*$", "")
	end
end

local function complete()
	local win = vis.win
	if not win or not win.file then return true end

	local head = prefix(win)
	if head == "" then return true end

	local seen, items = {}, {}
	add_words(items, seen, win.file:content(0, win.file.size), head)
	for _, path in ipairs(history.files(history_limit)) do
		if path ~= win.file.path then
			add_words(items, seen, read(path), head)
		end
	end

	local item = choose(items)
	if item and item:sub(1, #head) == head then
		vis:insert(item:sub(#head + 1))
	end
	return true
end

vis:map(vis.modes.INSERT, "<C-n>", complete, "complete word")
vis:map(vis.modes.REPLACE, "<C-n>", complete, "complete word")
