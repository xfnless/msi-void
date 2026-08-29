require("vis")
local vis = vis

-- 固定主题；要换就改这一行。
vis.events.subscribe(vis.events.INIT, function()
	vis:command("set theme mytheme-dark")
end)
