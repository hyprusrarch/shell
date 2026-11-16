------------------
---- MONITORS ----
------------------

hl.monitor({ output = "DP-1", mode = "1920x1080@144", position = "0x0", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "foot"
local fileManager = "nautilus"
local menu = "rofi -show drun"

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function ()
    hl.exec_cmd("swaync")
    hl.exec_cmd('env QT_QUICK_BACKEND=software QSG_RENDER_LOOP=basic QT_QUICK_CONTROLS_STYLE=Basic QS_DROP_EXPENSIVE_FONTS=1 QT_LOGGING_RULES="*.debug=false" QS_NO_RELOAD_POPUP=1 MALLOC_ARENA_MAX=2 MALLOC_TRIM_THRESHOLD_=131072 MALLOC_CONF=narenas:2,background_thread:true,dirty_decay_ms:5000,muzzy_decay_ms:5000 qs')
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd([==[wl-paste --type text --watch sh -c 'clip=$(cat); if [[ "$clip" != *"<img src="* && "$clip" != *"<meta http-equiv="* ]]; then echo -n "$clip" | cliphist store; fi']==])
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("fcitx5")
    hl.exec_cmd("systemctl --user disable warp-taskbar")
    hl.exec_cmd("sleep 1 ; systemctl --user stop warp-taskbar")
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("pipewire")
    hl.exec_cmd("pipewire-pulse")
    hl.exec_cmd("wireplumber")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------


hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Breeze")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("GTK_IM_MODULE", "fcitx5")
hl.env("QT_IM_MODULE", "fcitx5")
hl.env("XMODIFIERS", "@im=fcitx5")
hl.env("SDL_IM_MODULE", "fcitx5")
hl.env("ADW_DISABLE_PORTAL", "1")
hl.env("QML_DISABLE_DISK_CACHE", "0")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "0")
hl.env("QT_ENABLE_HIGHDPI_SCALING", "0")
hl.env("QT_SCALE_FACTOR", "1")
hl.env("QT_FONT_DPI", "84")
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1")
hl.env("LIBVA_DRIVER_NAME", "iHD")
hl.env("__GL_GSYNC_ALLOWED", "0")
hl.env("__GL_VRR_ALLOWED", "0")
hl.env("__GL_MaxFramesAllowed", "1")
hl.env("__GL_SYNC_TO_VBLANK", "0")
hl.env("__GL_YIELD", "NOTHING")
hl.env("__GL_SHADER_DISK_CACHE_SIZE", "10737418240")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 6,
        border_size = 3,
        col = {
            active_border = { colors = { "rgba(5e81acff)", "rgba(81a1c1ff)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
        resize_on_border = true,
        allow_tearing = true,
        layout = "dwindle",
    },
    decoration = {
        rounding = 5,
        active_opacity = 1.0,
        inactive_opacity = 0.8,
        shadow = {
            enabled = false,
            range = 0,
            render_power = 1,
            color = 0xee1a1a1a,
        },
        blur = {
            enabled = false,
            size = 0,
            passes = 0,
            vibrancy = 0,
        },
    },
    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear", { type = "bezier", points = { {0, 0}, {1, 1} } })
hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5}, {0.75, 1.0} } })
hl.curve("quick", { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

hl.config({
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = false,
        vrr = 0,
    },
    cursor = {
        no_hardware_cursors = true,
    },
    render = {
        direct_scanout = true,
    },
    opengl = {
        nvidia_anti_flicker = false,
    },
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.device({ name = "epic-mouse-v1", sensitivity = 1 })

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + X", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exit())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("~/.scripts/record.sh"))
hl.bind("F6", hl.dsp.exec_cmd("~/.scripts/autoclicker.sh"))
hl.bind("CTRL + ALT + DELETE", hl.dsp.exec_cmd("~/.config/quickshell/scripts/powermenu.sh"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("~/.scripts/bar.sh"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("~/.config/quickshell/scripts/launcher.sh"))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd([[rofi -modi emoji -show emoji -kb-secondary-copy "" -kb-custom-1 Ctrl+c -theme ~/.config/rofi/config.rasi]]))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/"))
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m window -o ~/Pictures/"))

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + F" .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})
