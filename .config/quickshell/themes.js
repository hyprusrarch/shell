.pragma library

var themes = {
    // ── ADAPTIVE THEME (PYWAL) ──
    "adaptive": { bgMain: "#000000", bgDark: "#111111", textMain: "#ffffff", textMuted: "#aaaaaa", accent: "#ffffff", accentAlt: "#dddddd", border: "#333333", error: "#ff0000", warning: "#ffff00", success: "#00ff00", info: "#0000ff" },

    "tokyo_night_storm": { bgMain: "#1a1b26", bgDark: "#16161e", textMain: "#c0caf5", textMuted: "#565f89", accent: "#7aa2f7", accentAlt: "#bb9af7", border: "#24283b", error: "#f7768e", warning: "#e0af68", success: "#9ece6a", info: "#89dceb" },

    // ── PERFECTED DARK THEMES ──
    "catppuccin_mocha": { bgMain: "#1e1e2e", bgDark: "#11111b", border: "#313244", textMain: "#cdd6f4", textMuted: "#a6adc8", accent: "#cba6f7", accentAlt: "#f5c2e7", error: "#f38ba8", warning: "#f9e2af", success: "#a6e3a1", info: "#89b4fa" },
    "dracula_classic": { bgMain: "#282a36", bgDark: "#21222c", border: "#44475a", textMain: "#f8f8f2", textMuted: "#a9b5d6", accent: "#bd93f9", accentAlt: "#ff79c6", error: "#ff6e6e", warning: "#f1fa8c", success: "#5af78e", info: "#9aedfe" },
    "nord_dark": { bgMain: "#2e3440", bgDark: "#242933", border: "#3b4252", textMain: "#e5e9f0", textMuted: "#9fb0c7", accent: "#88c0d0", accentAlt: "#b48ead", error: "#bf616a", warning: "#ebcb8b", success: "#a3be8c", info: "#81a1c1" },
    "gruvbox_dark": { bgMain: "#282828", bgDark: "#1d2021", border: "#3c3836", textMain: "#ebdbb2", textMuted: "#bdae93", accent: "#fe8019", accentAlt: "#d3869b", error: "#fb4934", warning: "#fabd2f", success: "#b8bb26", info: "#83a598" },
    "rose_pine": { bgMain: "#191724", bgDark: "#13111b", border: "#2a273f", textMain: "#e0def4", textMuted: "#a8a3c4", accent: "#c4a7e7", accentAlt: "#ebbcba", error: "#eb6f92", warning: "#f6c177", success: "#9ccfd8", info: "#31748f" },
    "everforest_dark": { bgMain: "#2d353b", bgDark: "#232a2e", border: "#3d484d", textMain: "#d3c6aa", textMuted: "#9ea8a1", accent: "#a7c080", accentAlt: "#d699b6", error: "#e67e80", warning: "#dbbc7f", success: "#83c092", info: "#7fbbb3" },
    "kanagawa": { bgMain: "#1f1f28", bgDark: "#16161d", border: "#363646", textMain: "#dcd7ba", textMuted: "#939082", accent: "#7e9cd8", accentAlt: "#957fb8", error: "#e82424", warning: "#e6c384", success: "#98bb6c", info: "#7fb4ca" },
    "ayu_mirage": { bgMain: "#212733", bgDark: "#171c24", border: "#2c3442", textMain: "#d9d7ce", textMuted: "#8793a3", accent: "#ffcc66", accentAlt: "#f28779", error: "#ff5555", warning: "#ffd580", success: "#a6cc70", info: "#5ccfe6" },
    "synthwave_84": { bgMain: "#2b213a", bgDark: "#1f172a", border: "#3c2d51", textMain: "#ffffff", textMuted: "#a88cd6", accent: "#36f9f6", accentAlt: "#f92aad", error: "#fe4450", warning: "#f8df72", success: "#72f1b8", info: "#03edf9" },
    "cyberpunk_2077": { bgMain: "#0f0f0f", bgDark: "#050505", border: "#222222", textMain: "#fcee0a", textMuted: "#aaaaaa", accent: "#05d5ff", accentAlt: "#ff003c", error: "#ff003c", warning: "#fcee0a", success: "#00ff00", info: "#05d5ff" },
    "midnight_purple": { bgMain: "#12121e", bgDark: "#0a0a0f", border: "#252538", textMain: "#f0e6f5", textMuted: "#bda8c9", accent: "#d6abff", accentAlt: "#ffd166", error: "#ff6b8b", warning: "#ffe08a", success: "#2ce8b7", info: "#3ac4eb" },
    "oled_black": { bgMain: "#000000", bgDark: "#000000", border: "#1c1c1c", textMain: "#e0e0e0", textMuted: "#999999", accent: "#ffffff", accentAlt: "#aaaaaa", error: "#ff6666", warning: "#ffcc66", success: "#66ff66", info: "#66ccff" },
    "macos_dark": { bgMain: "#1e1e1e", bgDark: "#121212", border: "#2c2c2c", textMain: "#ffffff", textMuted: "#999999", accent: "#0a84ff", accentAlt: "#ff375f", error: "#ff453a", warning: "#ffd60a", success: "#32d74b", info: "#64d2ff" },

    // ── HIGH CONTRAST LIGHT THEMES (Deep Jewel-Tone Status Colors) ──
    "minimal_light": { bgMain: "#f5f5f5", bgDark: "#ebebeb", border: "#ffffff", textMain: "#1a1a1a", textMuted: "#666666", accent: "#000000", accentAlt: "#333333", success: "#1c1c1c", warning: "#2b2b2b", info: "#3a3a3a", error: "#0f0f0f" },
    "lavender_mist": { bgMain: "#f5f0f6", bgDark: "#ebe2ed", border: "#ffffff", textMain: "#3d2b45", textMuted: "#755b82", accent: "#4a2663", accentAlt: "#6a358c", success: "#361b4d", warning: "#462266", info: "#572a80", error: "#241133" },
    "matcha_latte": { bgMain: "#f0f4f1", bgDark: "#e2e8e4", border: "#ffffff", textMain: "#203326", textMuted: "#526b5a", accent: "#1e5232", accentAlt: "#286b42", success: "#153822", warning: "#1c4a2d", info: "#235c38", error: "#0e2617" },
    "rose_water": { bgMain: "#fff0f3", bgDark: "#f5e1e5", border: "#ffffff", textMain: "#4a222c", textMuted: "#855b65", accent: "#7a1c35", accentAlt: "#9c2444", success: "#4a1220", warning: "#63172b", info: "#8a203c", error: "#360c17" },
    "sepia_ink": { bgMain: "#f5f0e6", bgDark: "#ebdcd0", border: "#ffffff", textMain: "#3d2f24", textMuted: "#756456", accent: "#5e381b", accentAlt: "#7a4923", success: "#382110", warning: "#4a2c15", info: "#6e411f", error: "#26160b" },
    "ocean_breeze": { bgMain: "#f0f6fc", bgDark: "#e1ecf7", border: "#ffffff", textMain: "#14293d", textMuted: "#4a6885", accent: "#0d4c80", accentAlt: "#1163a6", success: "#072f52", warning: "#0a3d6b", info: "#105a99", error: "#05223b" },
    "autumn_gold": { bgMain: "#fcf6f0", bgDark: "#f2e6db", border: "#ffffff", textMain: "#422013", textMuted: "#80523e", accent: "#8f3300", accentAlt: "#b34000", success: "#4a1a00", warning: "#6e2700", info: "#b34000", error: "#331200" },
    "nord_day": { bgMain: "#e5e9f0", bgDark: "#d8dee9", border: "#eceff4", textMain: "#2e3440", textMuted: "#4c566a", accent: "#34506b", accentAlt: "#416385", success: "#223547", warning: "#2b4259", info: "#3d5c7a", error: "#182531" },
    "blueberry_frost": { bgMain: "#e3f2fd", bgDark: "#bbdefb", border: "#ffffff", textMain: "#0d47a1", textMuted: "#1565c0", accent: "#1a237e", accentAlt: "#311b92", success: "#0a2e1d", warning: "#4a350e", info: "#0a1f4a", error: "#3d0b16" },
    "mint_choco_hc": { bgMain: "#e8f5e9", bgDark: "#c8e6c9", border: "#ffffff", textMain: "#3e2723", textMuted: "#5d4037", accent: "#1b5e20", accentAlt: "#3e2723", success: "#123d16", warning: "#3b2205", info: "#173342", error: "#3d1616" },
    "corporate_slate_hc": { bgMain: "#f1f5f9", bgDark: "#e2e8f0", border: "#ffffff", textMain: "#0f172a", textMuted: "#475569", accent: "#1e293b", accentAlt: "#334155", success: "#0f2e1b", warning: "#472e0a", info: "#0f1f3b", error: "#3b0a12" },
    "solarized_light_hc": { bgMain: "#fdf6e3", bgDark: "#eee8d5", border: "#ffffff", textMain: "#073642", textMuted: "#586e75", accent: "#268bd2", accentAlt: "#d33682", success: "#1c3809", warning: "#473803", info: "#0a2b42", error: "#4f0f0d" },
    "ayu_light_hc": { bgMain: "#fafafa", bgDark: "#f0f0f0", border: "#ffffff", textMain: "#3b434d", textMuted: "#747d87", accent: "#2578a6", accentAlt: "#c73e45", success: "#1a3809", warning: "#4a2a05", info: "#0d2b40", error: "#4a0b0f" }
};
