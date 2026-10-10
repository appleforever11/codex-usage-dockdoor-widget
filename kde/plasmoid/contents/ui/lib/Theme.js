// Codex Usage theme engine — a faithful port of CodexTheme.swift,
// CodexThemeVisuals.swift and the label formatting from CodexTokenUsage /
// CodexModelIdentity. Colors are [r,g,b] arrays in 0…1 space, exactly the
// values the SwiftUI widget used, so the plasmoid renders identical palettes.

.pragma library

const SHARED_PURPLE_GLOW = [0.54, 0.20, 0.90];

const THEMES = {
    "Astra": {
        key: "astra",
        displayName: "Astra",
        symbol: "sparkles",
        accent: [0.76, 0.48, 1.0],
        colors: [[0.38, 0.16, 0.85], [0.76, 0.48, 1.0], [0.98, 0.72, 1.0]],
        base: [0.055, 0.025, 0.12],
        dataColors: [[0.76, 0.48, 1.0], [0.98, 0.72, 1.0], [0.56, 0.28, 0.92], [0.93, 0.42, 0.90]],
        artworkBase: [0.065, 0.01, 0.18],
    },
    "Luna": {
        key: "luna",
        displayName: "Luna-6",
        symbol: "moon",
        accent: [0.40, 0.77, 1.0],
        colors: [[0.20, 0.36, 0.90], [0.40, 0.77, 1.0], [0.80, 0.91, 1.0]],
        base: [0.025, 0.055, 0.12],
        dataColors: [[0.40, 0.77, 1.0], [0.80, 0.91, 1.0], [0.25, 0.56, 0.98], [0.35, 0.84, 0.92]],
        artworkBase: [0.025, 0.055, 0.12],
    },
    "Sol": {
        key: "sol",
        displayName: "Sol-6",
        symbol: "sun",
        accent: [1.0, 0.61, 0.20],
        colors: [[0.85, 0.25, 0.10], [1.0, 0.61, 0.20], [1.0, 0.88, 0.49]],
        base: [0.13, 0.055, 0.025],
        dataColors: [[1.0, 0.61, 0.20], [1.0, 0.88, 0.49], [1.0, 0.38, 0.12], [0.96, 0.25, 0.16]],
        artworkBase: [0.13, 0.055, 0.025],
    },
    "Terra": {
        key: "terra",
        displayName: "Terra",
        symbol: "globe",
        accent: [0.30, 0.77, 0.52],
        colors: [[0.62, 0.36, 0.19], [0.30, 0.77, 0.52], [0.78, 0.87, 0.56]],
        base: [0.065, 0.08, 0.045],
        dataColors: [[0.30, 0.77, 0.52], [0.78, 0.87, 0.56], [0.24, 0.91, 0.59], [0.82, 0.68, 0.28]],
        artworkBase: [0.065, 0.08, 0.045],
    },
    "Rainbow": {
        key: "rainbow",
        displayName: "Rainbow",
        symbol: "rainbow",
        accent: [1.0, 0.41, 0.71],  // .pink
        colors: [
            [1.0, 0.41, 0.71], [1.0, 0.55, 0.20], [0.95, 0.77, 0.06],
            [0.19, 0.82, 0.35], [0.11, 0.68, 0.94], [0.60, 0.33, 0.85], [1.0, 0.41, 0.71],
        ],
        base: [0.07, 0.055, 0.10],
        dataColors: [
            [1.0, 0.41, 0.71], [1.0, 0.55, 0.20], [0.95, 0.77, 0.06],
            [0.19, 0.82, 0.35], [0.11, 0.68, 0.94], [0.60, 0.33, 0.85], [1.0, 0.41, 0.71],
        ],
        artworkBase: [0.07, 0.055, 0.10],
    },
};

const THEME_ORDER = ["Luna", "Sol", "Terra", "Astra", "Rainbow"];

function theme(name) {
    if (THEMES[name] !== undefined)
        return THEMES[name];
    const wanted = String(name);
    // Also resolve display names ("Luna-6") and lowercase keys ("luna") so a
    // stored theme string never silently falls back to Astra.
    const byDisplayName = Object.keys(THEMES).find(k => THEMES[k].displayName === wanted);
    if (byDisplayName !== undefined)
        return THEMES[byDisplayName];
    const byKey = Object.keys(THEMES).find(k => THEMES[k].key === wanted.toLowerCase());
    if (byKey !== undefined)
        return THEMES[byKey];
    return THEMES["Astra"];
}

// ---------------------------------------------------------------------------
// Derived themes — Plasma style and custom accent
// ---------------------------------------------------------------------------

function clamp01(v) { return Math.max(0, Math.min(1, v)); }

function hexToRgb(hex) {
    const s = String(hex || "").trim().replace(/^#/, "");
    if (!/^[0-9a-fA-F]{6}$/.test(s))
        return null;
    return [
        parseInt(s.slice(0, 2), 16) / 255,
        parseInt(s.slice(2, 4), 16) / 255,
        parseInt(s.slice(4, 6), 16) / 255,
    ];
}

function rgbToHex(c) {
    const part = v => ("0" + Math.round(clamp01(v) * 255).toString(16)).slice(-2);
    return "#" + part(c[0]) + part(c[1]) + part(c[2]);
}

function rgbToHsl(c) {
    const r = clamp01(c[0]), g = clamp01(c[1]), b = clamp01(c[2]);
    const max = Math.max(r, g, b), min = Math.min(r, g, b);
    let h = 0, s = 0;
    const l = (max + min) / 2;
    if (max !== min) {
        const d = max - min;
        s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
        if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
        else if (max === g) h = ((b - r) / d + 2) / 6;
        else h = ((r - g) / d + 4) / 6;
    }
    return [h, s, l];
}

function hslToRgb(h, s, l) {
    h = ((h % 1) + 1) % 1;
    s = clamp01(s);
    l = clamp01(l);
    if (s === 0)
        return [l, l, l];
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    const channel = t => {
        if (t < 1 / 6) return p + (q - p) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
        return p;
    };
    return [channel(h + 1 / 3), channel(h), channel(h - 1 / 3)];
}

// Build a full theme object around one accent color: a dark glass base
// tinted toward the accent, gradient stops on either side of it, and a data
// palette that rotates the hue for distinguishable series colors.
function deriveTheme(key, displayName, accent) {
    const hsl = rgbToHsl(accent);
    const h = hsl[0];
    const s = Math.max(0.30, Math.min(0.95, hsl[1]));
    return {
        key: key,
        displayName: displayName,
        symbol: "paint",
        accent: accent,
        colors: [
            hslToRgb(h, s, Math.max(0.16, hsl[2] - 0.26)),
            accent,
            hslToRgb(h, s * 0.55, Math.min(0.90, hsl[2] + 0.30)),
        ],
        base: hslToRgb(h, Math.min(0.50, s * 0.55), 0.055),
        dataColors: [
            accent,
            hslToRgb(h + 0.09, s * 0.9, 0.76),
            hslToRgb(h + 0.50, 0.62, 0.62),
            hslToRgb(h - 0.09, s, 0.60),
        ],
        artworkBase: hslToRgb(h, Math.min(0.60, s * 0.7), 0.07),
    };
}

// Preset accent swatches offered for the custom mode (in-widget and in the
// settings dialog) — macOS-tint-picker style, all readable on dark glass.
const ACCENT_PRESETS = [
    { name: "Blue",    value: "#4095E8" },
    { name: "Cyan",    value: "#3FC2C7" },
    { name: "Teal",    value: "#4DC7A0" },
    { name: "Green",   value: "#57B860" },
    { name: "Yellow",  value: "#D8B84A" },
    { name: "Amber",   value: "#E6953F" },
    { name: "Red",     value: "#E46055" },
    { name: "Pink",    value: "#E86A9C" },
    { name: "Purple",  value: "#9C6CE8" },
    { name: "Indigo",  value: "#6B7BE8" },
];

// Resolve the active theme for a view. `configuration` is
// Plasmoid.configuration; `plasmaPalette` (nullable) carries the live Plasma
// scheme colors ({accent, positive, negative} as [r,g,b]); `appleName` is the
// per-page theme used when the mode is the default Apple liquid glass.
function resolveTheme(configuration, plasmaPalette, appleName) {
    const mode = configuration ? String(configuration.themeMode || "apple") : "apple";
    if (mode === "plasma") {
        if (plasmaPalette && plasmaPalette.accent)
            return deriveTheme("plasma", "Plasma", plasmaPalette.accent);
    } else if (mode === "custom") {
        const rgb = hexToRgb(configuration ? configuration.customAccentColor : "");
        if (rgb)
            return deriveTheme("custom", "Custom", rgb);
    }
    return theme(appleName || "Astra");
}

// Preferred UI typeface. The user's machines ship Nerd-Font Hack; fall back
// through close relatives and finally to the system default (empty family).
// `preferred` is the user's explicit choice from the settings dialog and
// always wins when non-empty.
let _fontFamilyCache = null;
function fontFamily(preferred) {
    if (preferred !== undefined && preferred !== null && String(preferred).length > 0)
        return String(preferred);
    if (_fontFamilyCache !== null)
        return _fontFamilyCache;
    _fontFamilyCache = "";
    try {
        const installed = Qt.fontFamilies();
        const fallbacks = ["Hack Nerd Font", "Hack Nerd Font Mono", "JetBrainsMono Nerd Font", "Hack"];
        for (let i = 0; i < fallbacks.length; ++i) {
            if (installed.indexOf(fallbacks[i]) >= 0) {
                _fontFamilyCache = fallbacks[i];
                break;
            }
        }
    } catch (e) {}
    return _fontFamilyCache;
}

// Nerd Font icon glyphs — codepoint → icon verified by NAME against the
// Nerd Fonts glyph table AND existence in the installed Hack Nerd Font
// (existence alone is not enough: U+F1D3 exists but is the Git logo).
// Unknown names fall back to the gauge.
const ICON_GLYPHS = {
    gauge: "\uF04C5", speedometer: "\uF04C5", compass: "\uF14E",
    flame: "\uF06D", calendar: "\uF133", grid: "\uF00A", heatmap: "\uF00A",
    windows: "\uF0328", pulse: "\uF21E", health: "\uF21E", stethoscope: "\uF0F1",
    arrows: "\uF07D", list: "\uF03A", money: "\uF155", cpu: "\uF2DB",
    chart: "\uF201", folder: "\uF07B", person: "\uF007", check: "\uF00C",
    shield: "\uF132", terminal: "\uF120", chat: "\uF075", settings: "\uF013",
    clock: "\uF017", signal: "\uF012", bolt: "\uF0E7", paint: "\uF1FC",
    refresh: "\uF021", sliders: "\uF1DE", info: "\uF05A", external: "\uF08E",
    star: "\uF005", sun: "\uF185", moon: "\uF186",
};
function iconGlyph(name) {
    return ICON_GLYPHS[String(name || "").toLowerCase()] || ICON_GLYPHS.gauge;
}

function dataColor(t, index) {
    const palette = t.dataColors;
    const n = palette.length;
    const i = ((Math.trunc(index) % n) + n) % n;
    return palette[i];
}

function rgba(c, alpha) {
    return Qt.rgba(c[0], c[1], c[2], alpha === undefined ? 1 : alpha);
}

function mix(a, b, f) {
    return [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f];
}

// Semantic status tints from CodexTrackerStore.usageTint / statusTint.
function usageTint(percentRemaining) {
    if (percentRemaining >= 0.45)
        return [0.13, 0.72, 1.00];
    if (percentRemaining >= 0.20)
        return [1.0, 0.58, 0.0];       // orange
    return [1.0, 0.27, 0.21];          // red
}

function metricTint(t, key, fallback) {
    switch (key) {
    case "green": return [0.19, 0.82, 0.35];
    case "orange": return [1.0, 0.58, 0.0];
    case "red": return [1.0, 0.27, 0.21];
    case "blue": return [0.13, 0.72, 1.0];
    case "purple": return [0.60, 0.33, 0.85];
    case "accent": return t.accent;
    default: return fallback || [0.55, 0.57, 0.60];
    }
}

// ---------------------------------------------------------------------------
// Formatting ports
// ---------------------------------------------------------------------------

function compactTokens(tokens) {
    const value = Math.max(Number(tokens) || 0, 0);
    if (value >= 1e9)
        return (value / 1e9).toFixed(1) + "B";
    if (value >= 1e6)
        return (value / 1e6).toFixed(1) + "M";
    if (value >= 1e3)
        return (value / 1e3).toFixed(1) + "K";
    return String(Math.round(value));
}

function compactTokensPlain(tokens) {
    const value = Math.max(Number(tokens) || 0, 0);
    if (value >= 1e6)
        return (value / 1e6).toFixed(1) + "M";
    if (value >= 1e3)
        return (value / 1e3).toFixed(0) + "K";
    return String(Math.round(value));
}

function rateLabel(tokensPerMinute) {
    if (tokensPerMinute === null || tokensPerMinute === undefined || !isFinite(tokensPerMinute) || tokensPerMinute <= 0)
        return "—";
    return compactTokens(Math.round(tokensPerMinute)) + " / min";
}

function percentText(fraction) {
    return Math.round(Math.max(0, Math.min(1, fraction)) * 100) + "%";
}

function modelLabel(model, unknown) {
    const fallback = unknown || "Unknown model";
    if (model === null || model === undefined || model === "" || String(model).toLowerCase() === "unknown")
        return fallback;
    const value = String(model).toLowerCase();
    if (value.indexOf("spark") >= 0)
        return "Spark";
    const families = ["luna", "sol", "terra", "astra", "daybreak"];
    for (let i = 0; i < families.length; ++i) {
        if (value.indexOf(families[i]) >= 0) {
            const name = familyDisplay(families[i]);
            if (value.indexOf("gpt-") === 0) {
                const version = value.slice(4).split("-")[0];
                if (version.length > 0 && version[0] >= "0" && version[0] <= "9")
                    return name + "-" + version;
            }
            return name;
        }
    }
    return model;
}

// Model family helpers mirroring the helper's util::model_family so the
// widget's curated families stay in lockstep with the backend.
function modelFamily(id) {
    const value = String(id || "").toLowerCase();
    const families = ["luna", "sol", "terra", "astra", "spark", "daybreak"];
    for (let i = 0; i < families.length; ++i)
        if (value.indexOf(families[i]) >= 0)
            return families[i];
    return "other";
}

function familyDisplay(family) {
    const value = String(family || "");
    if (value.length === 0)
        return "Other";
    return value.charAt(0).toUpperCase() + value.slice(1);
}

// Fallback accents for families without a curated identity artwork.
const FAMILY_FALLBACK_ACCENTS = {
    spark: [1.0, 0.62, 0.24],
    daybreak: [0.36, 0.58, 1.0],
    other: [0.55, 0.57, 0.62],
};

// The theme identity an identity button shows for a model family: curated
// planet artwork for the known four, otherwise a derived accent theme.
function familyIdentity(family) {
    const curated = { luna: "Luna", sol: "Sol", terra: "Terra", astra: "Astra" };
    if (curated[family])
        return theme(curated[family]);
    const accent = FAMILY_FALLBACK_ACCENTS[family] || FAMILY_FALLBACK_ACCENTS.other;
    return deriveTheme(family, familyDisplay(family), accent);
}

function reasoningLabel(effort) {
    const value = String(effort || "").toLowerCase();
    if (value === "low" || value === "instant")
        return "Low";
    if (value === "xhigh")
        return "XHigh";
    if (value === "ultra")
        return "Ultra";
    if (value === "max")
        return "Max";
    if (value === "" || value === "unknown" || value === "null" || value === "undefined")
        return "Unknown";
    return effort.charAt(0).toUpperCase() + effort.slice(1);
}

function relativeTime(targetEpochSeconds, nowEpochSeconds) {
    const delta = (targetEpochSeconds - nowEpochSeconds);
    const future = delta > 0;
    let seconds = Math.abs(delta);
    let amount, unit;
    if (seconds < 10)
        return future ? "in moments" : "just now";
    if (seconds < 60) { amount = seconds; unit = "s"; }
    else if (seconds < 3600) { amount = Math.floor(seconds / 60); unit = "m"; }
    else if (seconds < 86400) { amount = Math.floor(seconds / 3600); unit = "h"; }
    else if (seconds < 86400 * 30) { amount = Math.floor(seconds / 86400); unit = "d"; }
    else if (seconds < 86400 * 365) { amount = Math.floor(seconds / (86400 * 30)); unit = "mo"; }
    else { amount = Math.floor(seconds / (86400 * 365)); unit = "y"; }
    return future ? "in " + amount + unit : amount + unit + " ago";
}

function resetSummary(resetEpoch, nowEpoch) {
    if (resetEpoch === null || resetEpoch === undefined)
        return "No reset time exposed locally yet";
    const interval = Math.max(resetEpoch - nowEpoch, 0);
    const days = Math.floor(interval / 86400);
    const hours = Math.floor((interval % 86400) / 3600);
    const minutes = Math.floor((interval % 3600) / 60);
    if (days > 0)
        return "Resets in " + days + "d " + hours + "h";
    if (hours > 0)
        return "Resets in " + hours + "h " + minutes + "m";
    return "Resets in " + minutes + "m";
}

function shortWeekday(dayKey) {
    // Matches CodexV6DateFormatting: parse the day key as a UTC date and
    // return its English weekday abbreviation.
    const parts = String(dayKey).split("-");
    if (parts.length !== 3)
        return String(dayKey).slice(-2);
    const date = new Date(Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])));
    const names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const index = date.getUTCDay();
    return names[index] || String(dayKey).slice(-2);
}

function shortUsageLabel(name) {
    const lower = String(name || "").toLowerCase();
    if (lower.indexOf("spark") >= 0)
        return "Spark";
    if (lower.indexOf("general") >= 0)
        return "General";
    return "Limit";
}

// Card metadata: title + icon per CodexV6CardID.
const CARDS = {
    quota: { title: "Quota", icon: "gauge" },
    pace: { title: "Quota pace", icon: "speedometer" },
    burn: { title: "Live burn", icon: "flame" },
    context: { title: "Context health", icon: "windows" },
    quotaBudget: { title: "Quota budget", icon: "gauge" },
    sessionPulse: { title: "Session pulse", icon: "pulse" },
    contextRunway: { title: "Context runway", icon: "arrows" },
    dailyActivity: { title: "Daily activity", icon: "calendar" },
    hourlyActivity: { title: "Hourly activity", icon: "grid" },
    projectHeatmap: { title: "Project heatmap", icon: "heatmap" },
    turnTimeline: { title: "Turn timeline", icon: "list" },
    streaksGoals: { title: "Streaks & goals", icon: "flame" },
    cost: { title: "Cost estimate", icon: "money" },
    modelMix: { title: "Model mix", icon: "cpu" },
    modelScorecard: { title: "Model scorecard", icon: "chart" },
    efficiency: { title: "Efficiency", icon: "gauge" },
    projectMix: { title: "Project mix", icon: "folder" },
    sessionHealth: { title: "Session health", icon: "pulse" },
    officialActivity: { title: "Official activity", icon: "person" },
    reliability: { title: "Reliability", icon: "check" },
    dataHealth: { title: "Data health", icon: "shield" },
    workspaceHealth: { title: "Workspace health", icon: "terminal" },
    recentChats: { title: "Recent chats", icon: "chat" },
    modelControls: { title: "New chat defaults", icon: "settings" },
};

const PAGE_DEFAULT_CARDS = {
    overview: ["quota", "modelControls", "quotaBudget", "sessionPulse", "pace", "burn", "context", "contextRunway"],
    activity: ["dailyActivity", "hourlyActivity", "projectHeatmap", "turnTimeline", "streaksGoals", "cost"],
    models: ["modelMix", "modelScorecard", "efficiency", "projectMix", "sessionHealth"],
    health: ["officialActivity", "reliability", "dataHealth", "workspaceHealth", "recentChats"],
};

const PAGE_DEFAULT_THEME = { overview: "Astra", activity: "Luna", models: "Terra", health: "Sol" };
const PAGES = [
    { id: "overview", title: "Overview", icon: "gauge" },
    { id: "activity", title: "Activity", icon: "chart" },
    { id: "models", title: "Models", icon: "cpu" },
    { id: "health", title: "Health", icon: "health" },
];

// Port of CodexV6CardOrderStore.normalizedLayout: keep one copy of each card,
// restore missing defaults, and repair duplicates.
function normalizedLayout(layout) {
    const seen = {};
    const result = {};
    for (let p = 0; p < PAGES.length; ++p) {
        const page = PAGES[p].id;
        const cards = (layout && layout[page]) || [];
        result[page] = [];
        for (let i = 0; i < cards.length; ++i) {
            const card = cards[i];
            if (!CARDS[card] || seen[card])
                continue;
            seen[card] = true;
            result[page].push(card);
        }
    }
    for (let p = 0; p < PAGES.length; ++p) {
        const page = PAGES[p].id;
        const defaults = PAGE_DEFAULT_CARDS[page];
        for (let i = 0; i < defaults.length; ++i) {
            if (!seen[defaults[i]]) {
                seen[defaults[i]] = true;
                result[page].push(defaults[i]);
            }
        }
    }
    return result;
}

function parseLayout(savedText) {
    try {
        const parsed = JSON.parse(savedText);
        if (parsed && typeof parsed === "object")
            return normalizedLayout(parsed);
    } catch (e) {}
    return normalizedLayout({});
}
