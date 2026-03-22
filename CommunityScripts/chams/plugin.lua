local settings = require("settings")

local Plugin = {}
Plugin.name = "Chams"
Plugin.description = "Highlights nearby entities with outline glow."
Plugin.author = "Community"

local DEFAULTS = {
    enabled = true,
    show_hostile = true,
    show_friendly = false,
    show_neutral = false,
    show_players = false,
    show_rares = true,
    show_quest = true,
    max_range = 40,
    max_highlights = 5,
}

local cfg = {}

function Plugin.onEnable()
    cfg = settings.load("chams", DEFAULTS)
end

function Plugin.onDisable()
    for i = 0, 4 do
        game.outline_clear(i)
    end
    settings.save("chams", cfg)
end

function Plugin.onTick()
end

function Plugin.onDraw()
end

return Plugin
