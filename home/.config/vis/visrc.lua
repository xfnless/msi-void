local home = os.getenv("HOME") or "."
local config = home .. "/.config/vis"

package.path = config .. "/?.lua;" .. config .. "/?/init.lua;" .. package.path

require("vis")
pcall(require, "plugins/filetype")

local formatter = require("my.formatter")
local navigate = require("my.navigate")
local entry = require("my.entry")
local toggle = require("my.toggle")
require("my.theme")
require("my.completion")
require("my.cursor")
require("my.fcitx")
require("my.history")
require("my.lock")
require("my.status")

vis.events.subscribe(vis.events.INIT, function()
	entry.setup({
		root = os.getenv("VIS_ZK_ROOT") or (home .. "/Drafts/memo"),
	})
	vis:map(vis.modes.NORMAL, " y", "<vis-register>+<vis-operator-yank>", "yank to system clipboard")
	vis:map(vis.modes.VISUAL, " y", "<vis-register>+<vis-operator-yank>", "yank to system clipboard")
	vis:map(vis.modes.NORMAL, " p", "<vis-register>+<vis-put-after>", "paste from system clipboard")
	vis:map(vis.modes.VISUAL, " p", "<vis-register>+<vis-put-after>", "paste from system clipboard")
	local function search_context()
		if entry.search_token() then
			return true
		end
		return navigate.grep_word()
	end
	vis:map(vis.modes.NORMAL, "<Enter>", search_context, "search context")
	vis:map(vis.modes.VISUAL, "<Enter>", navigate.grep_word, "grep selection")
	vis:map(vis.modes.NORMAL, "gf", navigate.gf, "open file under cursor")
	vis:map(vis.modes.NORMAL, "gx", navigate.url, "open url under cursor")
	vis:map(vis.modes.NORMAL, " h", navigate.history, "history")
	vis:map(vis.modes.NORMAL, " b", navigate.back, "previous history")
	vis:map(vis.modes.NORMAL, " f", navigate.file, "project files")
	vis:map(vis.modes.NORMAL, " d", navigate.grep, "project grep")
	vis:map(vis.modes.NORMAL, " g", navigate.grep_history, "history grep")
	vis:map(vis.modes.NORMAL, " j", entry.new_entry, "new entry")
	vis:map(vis.modes.VISUAL, " j", entry.new_entry, "new entry from selection")
	vis:command_register("new-entry", entry.new_entry, "new entry")
	vis:map(vis.modes.NORMAL, " l", entry.open_entries, "entries")
	vis:map(vis.modes.NORMAL, " t", toggle.boolean, "toggle true/false")

	local function format()
		formatter.format()
		return true
	end
	vis:map(vis.modes.NORMAL, "=", format, "format")
end)

vis.events.subscribe(vis.events.WIN_OPEN, function()
	vis:command("set autoindent on")
	vis:command("set tabwidth 4")
end)
