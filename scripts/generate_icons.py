"""Regenereaza toate icoanele din assets/images/schoolmate_logo.png."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "images" / "schoolmate_logo.png"

src = Image.open(SRC).convert("RGBA")
print(f"Source: {SRC} ({src.size[0]}x{src.size[1]})")


def save_resized(target: Path, size: int) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    img = src.resize((size, size), Image.LANCZOS)
    img.save(target, "PNG")
    print(f"  -> {target.relative_to(ROOT)} ({size}x{size})")


def save_padded(target: Path, size: int, content_ratio: float = 0.66) -> None:
    """For Android adaptive foreground: shrink logo into safe zone, transparent padding."""
    target.parent.mkdir(parents=True, exist_ok=True)
    inner = max(1, int(round(size * content_ratio)))
    img = src.resize((inner, inner), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = (size - inner) // 2
    canvas.paste(img, (offset, offset), img)
    canvas.save(target, "PNG")
    print(f"  -> {target.relative_to(ROOT)} ({size}x{size}, padded inner={inner})")


def flatten_white(target: Path, size: int) -> None:
    """For iOS/macOS icons that should be opaque (no alpha)."""
    target.parent.mkdir(parents=True, exist_ok=True)
    img = src.resize((size, size), Image.LANCZOS)
    bg = Image.new("RGB", (size, size), (255, 255, 255))
    bg.paste(img, mask=img.split()[3] if img.mode == "RGBA" else None)
    bg.save(target, "PNG")
    print(f"  -> {target.relative_to(ROOT)} ({size}x{size}, flat)")


print("\n[Web]")
web_targets = {
    "web/favicon.png": 32,
    "web/favicon-schoolmate.png": 32,
    "web/icons/Icon-192.png": 192,
    "web/icons/Icon-512.png": 512,
    "web/icons/Icon-maskable-192.png": 192,
    "web/icons/Icon-maskable-512.png": 512,
    "web/icons/schoolmate-192.png": 192,
    "web/icons/schoolmate-512.png": 512,
    "web/icons/schoolmate-maskable-192.png": 192,
    "web/icons/schoolmate-maskable-512.png": 512,
    "web/icons/logo_1024x1024.png": 1024,
}
for rel, size in web_targets.items():
    save_resized(ROOT / rel, size)

print("\n[Android]")
android_sizes = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}
for density, (launcher, foreground) in android_sizes.items():
    base = ROOT / f"android/app/src/main/res/mipmap-{density}"
    save_resized(base / "ic_launcher.png", launcher)
    save_padded(base / "ic_launcher_foreground.png", foreground)

print("\n[iOS]")
ios_base = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
ios_targets = {
    "Icon-App-1024x1024@1x.png": 1024,
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
}
for name, size in ios_targets.items():
    flatten_white(ios_base / name, size)

print("\n[macOS]")
mac_base = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
mac_sizes = [16, 32, 64, 128, 256, 512, 1024]
for size in mac_sizes:
    save_resized(mac_base / f"app_icon_{size}.png", size)

print("\nGata.")
