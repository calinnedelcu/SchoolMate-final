"""
Second-pass color tuning: brighten the deep navy blues that came out of
the green->blue conversion so the brand feels like a friendly sky-blue
school app instead of a corporate-navy one.

What it does:
- Walks all .dart files in lib/
- For every Color(0xAARRGGBB) literal in the blue band (hue 195°-230°),
  shifts the hue toward sky blue (~205°) and lifts the lightness:
    * Very dark (L < 0.32)        -> push toward L = 0.46  (medium-bright blue)
    * Dark/medium (0.32 <= L < 0.55) -> push toward L = 0.55-0.60
    * Already light (L >= 0.78)   -> leave alone (keeps surface tints)
    * Mid lightness               -> small lift, mostly preserved
- Saturation is gently boosted for the brand range so the blues feel
  vibrant instead of muted.
- Alpha is preserved.
- Pure neutrals (saturation < 0.06) are skipped, as are non-blue hues.

Result: brand primary lands around #1E88E5 / #2196F3 territory (Material
Light Blue 600/500), surface tints stay subtle, shadows stay soft.
"""

import os
import re
import colorsys

ROOT = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib")
)

COLOR_RE = re.compile(r"0x([0-9A-Fa-f]{6,8})")

# Blue band we will retune (where the green->blue script landed everything).
BLUE_HUE_MIN = 195.0
BLUE_HUE_MAX = 235.0

# Target hue: sky blue, slightly cooler than cyan, warmer than indigo.
TARGET_HUE = 205.0


def retune(hex_str: str) -> str:
    raw = hex_str
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

    # Skip near-grays
    if s < 0.06:
        return hex_str

    # Only retune blues that came from the prior conversion
    if h_deg < BLUE_HUE_MIN or h_deg > BLUE_HUE_MAX:
        return hex_str

    # Pull hue toward sky blue (not all the way — keep some natural variation)
    new_h_deg = h_deg + (TARGET_HUE - h_deg) * 0.7

    # Lightness curve
    if l < 0.32:
        # Brand-dark territory -> push to a vibrant medium-bright blue
        new_l = 0.46 + (l * 0.25)  # spreads 0.0..0.32 -> 0.46..0.54
    elif l < 0.55:
        # Dark-mid -> lift to mid-bright
        new_l = 0.55 + (l - 0.32) * 0.6  # 0.32..0.55 -> 0.55..0.69
    elif l < 0.78:
        # Mid -> small lift
        new_l = l + 0.04
    else:
        # Already light surface tints -> leave alone
        new_l = l

    new_l = max(0.0, min(1.0, new_l))

    # Saturation: boost mid-range a bit so brand feels vibrant, not muted
    if s < 0.85:
        new_s = min(1.0, s + 0.18 * (1.0 - s))
    else:
        new_s = s

    nr, ng, nb = colorsys.hls_to_rgb(new_h_deg / 360.0, new_l, new_s)
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
        new_inner = retune(original_inner)
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
    for dirpath, _, filenames in os.walk(ROOT):
        for name in filenames:
            if not name.endswith(".dart"):
                continue
            full = os.path.join(dirpath, name)
            n = process_file(full)
            if n > 0:
                total_files += 1
                total_changes += n
    print(f"Files modified: {total_files}")
    print(f"Total color literals retuned: {total_changes}")


if __name__ == "__main__":
    main()
