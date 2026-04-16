"""
Convert all green colors to blue across .dart files in lib/.

Strategy: parse Color(0xAARRGGBB) literals, convert to HSV. If hue is in
the green range (70-170 deg), rotate it into the blue range (~210 deg)
while preserving saturation and lightness. Non-green colors are left
untouched (reds, oranges, yellows, purples, plain neutrals, already-blue
shades).
"""

import os
import re
import colorsys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib")
ROOT = os.path.normpath(ROOT)

# Match Color(0xFFRRGGBB), Color(0xAARRGGBB), Color(0xRRGGBB)
COLOR_RE = re.compile(r"0x([0-9A-Fa-f]{6,8})")

# Pure green hue range (deg). Generous so we catch teal-leaning greens too,
# but stop before cyan (~180).
GREEN_HUE_MIN = 70.0
GREEN_HUE_MAX = 175.0

# Target blue hue range. We map the green band onto the blue band so that
# darker forest greens stay darker (deeper blue) and brighter mints stay
# brighter (lighter blue), preserving the relative palette structure.
BLUE_HUE_TARGET_MIN = 205.0
BLUE_HUE_TARGET_MAX = 220.0


def map_hue(h_deg: float) -> float:
    if h_deg < GREEN_HUE_MIN or h_deg > GREEN_HUE_MAX:
        return h_deg
    t = (h_deg - GREEN_HUE_MIN) / (GREEN_HUE_MAX - GREEN_HUE_MIN)
    return BLUE_HUE_TARGET_MIN + t * (BLUE_HUE_TARGET_MAX - BLUE_HUE_TARGET_MIN)


def convert_one(hex_str: str) -> str:
    raw = hex_str
    # Normalize alpha
    if len(raw) == 6:
        a = None
        rgb_hex = raw
    elif len(raw) == 8:
        a = raw[:2]
        rgb_hex = raw[2:]
    else:
        return hex_str

    r = int(rgb_hex[0:2], 16) / 255.0
    g = int(rgb_hex[2:4], 16) / 255.0
    b = int(rgb_hex[4:6], 16) / 255.0

    h, l, s = colorsys.rgb_to_hls(r, g, b)
    h_deg = h * 360.0

    # Skip very gray colors (saturation low) — they're neutrals and shouldn't
    # be repainted blue. But for very light/dark grays we still want to keep
    # them as-is.
    if s < 0.06:
        return hex_str

    if h_deg < GREEN_HUE_MIN or h_deg > GREEN_HUE_MAX:
        return hex_str

    new_h_deg = map_hue(h_deg)
    new_h = new_h_deg / 360.0

    nr, ng, nb = colorsys.hls_to_rgb(new_h, l, s)
    nr_i = max(0, min(255, round(nr * 255)))
    ng_i = max(0, min(255, round(ng * 255)))
    nb_i = max(0, min(255, round(nb * 255)))

    new_rgb_hex = f"{nr_i:02X}{ng_i:02X}{nb_i:02X}"
    if a is not None:
        return a.upper() + new_rgb_hex
    return new_rgb_hex


def process_file(path: str) -> int:
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    changes = 0

    def repl(m):
        nonlocal changes
        original_inner = m.group(1)
        new_inner = convert_one(original_inner)
        if new_inner.upper() != original_inner.upper():
            changes += 1
            return "0x" + new_inner
        return m.group(0)

    new_text = COLOR_RE.sub(repl, text)
    if changes > 0:
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(new_text)
    return changes


def main():
    total_files = 0
    total_changes = 0
    touched = []
    for dirpath, _, filenames in os.walk(ROOT):
        for name in filenames:
            if not name.endswith(".dart"):
                continue
            full = os.path.join(dirpath, name)
            n = process_file(full)
            if n > 0:
                touched.append((full, n))
                total_files += 1
                total_changes += n
    print(f"Files modified: {total_files}")
    print(f"Total color literals rewritten: {total_changes}")
    for p, n in touched:
        rel = os.path.relpath(p, ROOT)
        print(f"  {rel}: {n}")


if __name__ == "__main__":
    main()
