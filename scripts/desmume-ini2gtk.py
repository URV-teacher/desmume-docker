#!/usr/bin/env python3
"""
Apply a DeSmuME (Windows) desmume.ini to the config of the GTK frontend.

The Windows build stores key bindings as Windows virtual-key codes in [Controls], while the GTK frontend reads
GDK keyvals from the [KEYS] group of ~/.config/desmume/config, and view/HUD/audio options from
~/.config/desmume/config.cfg. This script translates the former into the latter.

Usage: desmume-ini2gtk.py <desmume.ini> [config_dir]
"""

import configparser
import sys
from pathlib import Path

# GTK key names (order and names from DeSmuME's ctrlssdl.cpp) and its default GDK keyvals (gtk/main.cpp)
GTK_DEFAULT_KEYS = {
    "A": 0x078,  # x
    "B": 0x07A,  # z
    "Select": 0xFFE2,  # Shift_R
    "Start": 0xFF0D,  # Return
    "Right": 0xFF53,
    "Left": 0xFF51,
    "Up": 0xFF52,
    "Down": 0xFF54,
    "R": 0x077,  # w
    "L": 0x071,  # q
    "X": 0x073,  # s
    "Y": 0x061,  # a
    "Debug": 0x070,  # p
    "Boost": 0x06F,  # o
    "Lid": 0xFF08,  # BackSpace
}

# Windows virtual-key code -> GDK keyval
VK_TO_GDK = {
    0x08: 0xFF08,  # Backspace
    0x09: 0xFF09,  # Tab
    0x0D: 0xFF0D,  # Return
    0x10: 0xFFE1,  # Shift
    0x11: 0xFFE3,  # Control
    0x12: 0xFFE9,  # Alt
    0x1B: 0xFF1B,  # Escape
    0x20: 0x020,  # Space
    0x21: 0xFF55,  # Page Up
    0x22: 0xFF56,  # Page Down
    0x23: 0xFF57,  # End
    0x24: 0xFF50,  # Home
    0x25: 0xFF51,  # Left
    0x26: 0xFF52,  # Up
    0x27: 0xFF53,  # Right
    0x28: 0xFF54,  # Down
    0x2D: 0xFF63,  # Insert
    0x2E: 0xFFFF,  # Delete
    0x6A: 0xFFAA,  # Numpad *
    0x6B: 0xFFAB,  # Numpad +
    0x6D: 0xFFAD,  # Numpad -
    0x6E: 0xFFAE,  # Numpad .
    0x6F: 0xFFAF,  # Numpad /
    0xA0: 0xFFE1,  # Left Shift
    0xA1: 0xFFE2,  # Right Shift
    0xA2: 0xFFE3,  # Left Control
    0xA3: 0xFFE4,  # Right Control
    0xBA: 0x03B,  # ;
    0xBB: 0x03D,  # =
    0xBC: 0x02C,  # ,
    0xBD: 0x02D,  # -
    0xBE: 0x02E,  # .
    0xBF: 0x02F,  # /
    0xC0: 0x060,  # `
    0xDB: 0x05B,  # [
    0xDC: 0x05C,  # backslash
    0xDD: 0x05D,  # ]
    0xDE: 0x027,  # '
}
VK_TO_GDK.update({vk: vk for vk in range(0x30, 0x3A)})  # 0-9
VK_TO_GDK.update({vk: vk + 0x20 for vk in range(0x41, 0x5B)})  # A-Z -> a-z
VK_TO_GDK.update({vk: 0xFFB0 + vk - 0x60 for vk in range(0x60, 0x6A)})  # Numpad 0-9
VK_TO_GDK.update({vk: 0xFFBE + vk - 0x70 for vk in range(0x70, 0x7C)})  # F1-F12

# (ini section, ini key) -> (config.cfg group, key), for boolean HUD options
HUD_OPTIONS = {
    ("Display", "Display Fps"): ("HudDisplay", "Fps"),
    ("Display", "FrameCounter"): ("HudDisplay", "FrameCounter"),
    ("Display", "Display Lag Counter"): ("HudDisplay", "LagCounter"),
    ("Display", "Display Input"): ("HudDisplay", "Input"),
    ("Display", "Display Graphical Input"): ("HudDisplay", "GraphicalInput"),
    ("Display", "Display RTC"): ("HudDisplay", "RTC"),
    ("Display", "Display Microphone"): ("HudDisplay", "Mic"),
}


def log(msg: str) -> None:
    print(f"[desmume-ini2gtk] {msg}", file=sys.stderr)


def new_parser() -> configparser.RawConfigParser:
    parser = configparser.RawConfigParser(strict=False, delimiters=("=",), comment_prefixes=("#", ";"))
    parser.optionxform = str  # keys are case-sensitive
    return parser


def read_int(ini: configparser.RawConfigParser, section: str, key: str) -> int | None:
    try:
        return int(ini.get(section, key))
    except (configparser.Error, ValueError):
        return None


def build_keys(ini: configparser.RawConfigParser) -> dict[str, int]:
    keys = dict(GTK_DEFAULT_KEYS)
    for name in keys:
        vk = read_int(ini, "Controls", name)
        if not vk:  # missing or 0 (unassigned): keep the GTK default
            continue
        if vk not in VK_TO_GDK:
            log(f"Unknown Windows key code {vk} for '{name}', keeping default")
            continue
        keys[name] = VK_TO_GDK[vk]
    return keys


def build_options(ini: configparser.RawConfigParser) -> dict[tuple[str, str], str]:
    options: dict[tuple[str, str], str] = {}
    for (section, key), target in HUD_OPTIONS.items():
        value = read_int(ini, section, key)
        if value is not None:
            options[target] = "true" if value else "false"

    gap = read_int(ini, "Display", "ScreenGap")
    if gap is not None:
        options[("View", "ScreenGap")] = "true" if gap > 0 else "false"

    rotation = read_int(ini, "Video", "Window Rotate")
    if rotation in (0, 90, 180, 270):
        options[("View", "Rotation")] = str(rotation)

    interpolation = read_int(ini, "Sound", "SPUInterpolation")
    if interpolation in (0, 1, 2):
        options[("Audio", "Interpolation")] = str(interpolation)
    return options


def write(parser: configparser.RawConfigParser, path: Path) -> None:
    with path.open("w") as f:
        parser.write(f, space_around_delimiters=False)


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    ini_path = Path(sys.argv[1])
    config_dir = Path(sys.argv[2]) if len(sys.argv) == 3 else Path.home() / ".config" / "desmume"

    ini = new_parser()
    try:
        # Windows builds may write a BOM and non-UTF-8 paths
        ini.read_string(ini_path.read_text(encoding="utf-8-sig", errors="replace"))
    except (OSError, configparser.Error) as e:
        log(f"Cannot read {ini_path}: {e}")
        return 1
    config_dir.mkdir(parents=True, exist_ok=True)

    # Key bindings: DeSmuME needs every key of the group, otherwise it stops reading at the first missing one
    keys_path = config_dir / "config"
    keys_cfg = new_parser()
    keys_cfg.read(keys_path)
    keys_cfg.remove_section("KEYS")
    keys_cfg.add_section("KEYS")
    for name, keyval in build_keys(ini).items():
        keys_cfg.set("KEYS", name, str(keyval))
    write(keys_cfg, keys_path)

    # View/HUD/audio options: merge into the existing config.cfg, keeping the rest of options
    options_path = config_dir / "config.cfg"
    options_cfg = new_parser()
    options_cfg.read(options_path)
    for (group, key), value in build_options(ini).items():
        if not options_cfg.has_section(group):
            options_cfg.add_section(group)
        options_cfg.set(group, key, value)
    write(options_cfg, options_path)

    log(f"Applied {ini_path} to {config_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
