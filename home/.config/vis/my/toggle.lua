require("vis")
local vis = vis

local M = {}

local values = {
	["true"] = "false",
	["false"] = "true",
	True = "False",
	False = "True",
	TRUE = "FALSE",
	FALSE = "TRUE",
}

local function range_at_cursor(win)
	local file = win and win.file
	local selection = win and win.selection
	if not file or not selection then
		return nil
	end

	local range = file:text_object_word(selection.pos)
	if not range and selection.pos > 0 then
		range = file:text_object_word(selection.pos - 1)
	end
	if not range or range.start == range.finish then
		return nil
	end
	return range
end

function M.boolean()
	local win = vis.win
	local range = range_at_cursor(win)
	if not range then
		return true
	end

	local text = win.file:content(range)
	local replacement = values[text]
	if not replacement then
		return true
	end

	win.file:delete(range)
	win.file:insert(range.start, replacement)
	win.selection.pos = range.start
	return true
end

return M
