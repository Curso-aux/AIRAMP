import os
import json
from PIL import Image, ImageDraw

def create_icons():
    project_root = os.path.dirname(os.path.abspath(__file__))
    if os.path.basename(project_root) == 'scripts':
        repo_root = os.path.dirname(project_root)
    else:
        repo_root = project_root

    # Source image: Prefer aira_mascot_logo.png, fallback to aira_logo.png
    mascot_path = os.path.join(repo_root, 'airamp_flutter', 'assets', 'images', 'aira_mascot_logo.png')
    logo_path = os.path.join(repo_root, 'airamp_flutter', 'assets', 'images', 'aira_logo.png')

    if os.path.exists(mascot_path):
        source_path = mascot_path
        source_name = 'aira_mascot_logo.png'
    elif os.path.exists(logo_path):
        source_path = logo_path
        source_name = 'aira_logo.png'
    else:
        raise FileNotFoundError("No source logo found!")

    raw_img = Image.open(source_path).convert('RGBA')

    # Detect visible bounding box (ignoring stray alpha noise < 15)
    a_channel = raw_img.split()[3]
    thresh = a_channel.point(lambda p: 255 if p > 15 else 0)
    bbox = thresh.getbbox()
    if bbox:
        cropped = raw_img.crop(bbox)
    else:
        cropped = raw_img

    cw, ch = cropped.size
    # Create a centered square version of the artwork
    max_dim = max(cw, ch)
    square_logo = Image.new('RGBA', (max_dim, max_dim), (0, 0, 0, 0))
    square_logo.paste(cropped, ((max_dim - cw) // 2, (max_dim - ch) // 2), cropped)

    # Background color: Deep calm slate-charcoal #0A1420 matching AppTheme.darkBackground
    bg_color = (10, 20, 32, 255)
    bg_color_rgb = (10, 20, 32)

    res_dir = os.path.join(repo_root, 'airamp_flutter', 'android', 'app', 'src', 'main', 'res')

    # Android mipmap densities: (legacy_icon_size, adaptive_fg_size)
    densities = {
        'mipmap-mdpi': (48, 108),
        'mipmap-hdpi': (72, 162),
        'mipmap-xhdpi': (96, 216),
        'mipmap-xxhdpi': (144, 324),
        'mipmap-xxxhdpi': (192, 432),
    }

    print(f"Generating icons from {source_name} (artwork: {cw}x{ch})...")

    # 1. Android Icons
    for folder, (icon_size, fg_size) in densities.items():
        folder_path = os.path.join(res_dir, folder)
        os.makedirs(folder_path, exist_ok=True)

        # 1a. Legacy ic_launcher.png (Rounded/Circular with background)
        legacy = Image.new('RGBA', (icon_size, icon_size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(legacy)
        draw.ellipse([1, 1, icon_size - 2, icon_size - 2], fill=bg_color)
        
        inner_size = int(icon_size * 0.82)
        scaled_logo = square_logo.resize((inner_size, inner_size), Image.Resampling.LANCZOS)
        offset = (icon_size - inner_size) // 2
        legacy.paste(scaled_logo, (offset, offset), scaled_logo)
        legacy.save(os.path.join(folder_path, 'ic_launcher.png'), 'PNG')

        # 1b. Round ic_launcher_round.png
        round_icon = Image.new('RGBA', (icon_size, icon_size), (0, 0, 0, 0))
        r_draw = ImageDraw.Draw(round_icon)
        r_draw.ellipse([0, 0, icon_size - 1, icon_size - 1], fill=bg_color)
        round_icon.paste(scaled_logo, (offset, offset), scaled_logo)
        round_icon.save(os.path.join(folder_path, 'ic_launcher_round.png'), 'PNG')

        # 1c. Adaptive icon foreground ic_launcher_foreground.png
        # Scaled to 56% so it fits safely within Android's 66dp/72dp mask circle without any clipping
        fg = Image.new('RGBA', (fg_size, fg_size), (0, 0, 0, 0))
        fg_content_size = int(fg_size * 0.56)
        scaled_fg_logo = square_logo.resize((fg_content_size, fg_content_size), Image.Resampling.LANCZOS)
        fg_offset = (fg_size - fg_content_size) // 2
        fg.paste(scaled_fg_logo, (fg_offset, fg_offset), scaled_fg_logo)
        fg.save(os.path.join(folder_path, 'ic_launcher_foreground.png'), 'PNG')

    # Values colors.xml
    values_dir = os.path.join(res_dir, 'values')
    os.makedirs(values_dir, exist_ok=True)
    with open(os.path.join(values_dir, 'colors.xml'), 'w', encoding='utf-8') as f:
        f.write("""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0A1420</color>
</resources>
""")

    # Adaptive XMLs
    anydpi_dir = os.path.join(res_dir, 'mipmap-anydpi-v26')
    os.makedirs(anydpi_dir, exist_ok=True)
    adaptive_xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
    with open(os.path.join(anydpi_dir, 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
        f.write(adaptive_xml)
    with open(os.path.join(anydpi_dir, 'ic_launcher_round.xml'), 'w', encoding='utf-8') as f:
        f.write(adaptive_xml)

    # 2. Web icons
    web_icons_dir = os.path.join(repo_root, 'airamp_flutter', 'web', 'icons')
    os.makedirs(web_icons_dir, exist_ok=True)
    for size, name in [(192, 'Icon-192.png'), (512, 'Icon-512.png')]:
        web_im = Image.new('RGBA', (size, size), bg_color)
        content_size = int(size * 0.82)
        scaled = square_logo.resize((content_size, content_size), Image.Resampling.LANCZOS)
        offset = (size - content_size) // 2
        web_im.paste(scaled, (offset, offset), scaled)
        web_im.save(os.path.join(web_icons_dir, name), 'PNG')

    for size, name in [(192, 'Icon-maskable-192.png'), (512, 'Icon-maskable-512.png')]:
        web_im = Image.new('RGBA', (size, size), bg_color)
        content_size = int(size * 0.60)
        scaled = square_logo.resize((content_size, content_size), Image.Resampling.LANCZOS)
        offset = (size - content_size) // 2
        web_im.paste(scaled, (offset, offset), scaled)
        web_im.save(os.path.join(web_icons_dir, name), 'PNG')

    # Web favicon
    fav = Image.new('RGBA', (64, 64), bg_color)
    content_size = int(64 * 0.85)
    scaled = square_logo.resize((content_size, content_size), Image.Resampling.LANCZOS)
    offset = (64 - content_size) // 2
    fav.paste(scaled, (offset, offset), scaled)
    fav.save(os.path.join(repo_root, 'airamp_flutter', 'web', 'favicon.png'), 'PNG')

    # 3. Windows ICO
    win_res_dir = os.path.join(repo_root, 'airamp_flutter', 'windows', 'runner', 'resources')
    if os.path.exists(win_res_dir):
        ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
        ico_images = []
        for s in ico_sizes:
            im = Image.new('RGBA', s, bg_color)
            cs = int(s[0] * 0.82)
            sc = square_logo.resize((cs, cs), Image.Resampling.LANCZOS)
            off = (s[0] - cs) // 2
            im.paste(sc, (off, off), sc)
            ico_images.append(im)
        ico_images[0].save(os.path.join(win_res_dir, 'app_icon.ico'), format='ICO', sizes=ico_sizes)

    # 4. iOS icons
    ios_set_dir = os.path.join(repo_root, 'airamp_flutter', 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    ios_json_path = os.path.join(ios_set_dir, 'Contents.json')
    if os.path.exists(ios_json_path):
        with open(ios_json_path, 'r', encoding='utf-8') as f:
            ios_contents = json.load(f)
        for entry in ios_contents.get('images', []):
            fname = entry.get('filename')
            if not fname:
                continue
            size_parts = entry['size'].split('x')
            w = float(size_parts[0])
            scale = float(entry['scale'].replace('x', ''))
            px = int(round(w * scale))
            
            # iOS requires opaque image (RGB)
            im = Image.new('RGB', (px, px), bg_color_rgb)
            cs = int(px * 0.80)
            if cs < 1:
                cs = 1
            sc = square_logo.resize((cs, cs), Image.Resampling.LANCZOS)
            off = (px - cs) // 2
            im.paste(sc, (off, off), sc)
            im.save(os.path.join(ios_set_dir, fname), 'PNG')

    # 5. macOS icons
    macos_set_dir = os.path.join(repo_root, 'airamp_flutter', 'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    macos_json_path = os.path.join(macos_set_dir, 'Contents.json')
    if os.path.exists(macos_json_path):
        with open(macos_json_path, 'r', encoding='utf-8') as f:
            macos_contents = json.load(f)
        for entry in macos_contents.get('images', []):
            fname = entry.get('filename')
            if not fname:
                continue
            size_parts = entry['size'].split('x')
            w = float(size_parts[0])
            scale = float(entry['scale'].replace('x', ''))
            px = int(round(w * scale))

            im = Image.new('RGBA', (px, px), (0, 0, 0, 0))
            draw = ImageDraw.Draw(im)
            draw.rounded_rectangle([0, 0, px - 1, px - 1], radius=max(2, int(px * 0.22)), fill=bg_color)
            cs = int(px * 0.78)
            if cs < 1:
                cs = 1
            sc = square_logo.resize((cs, cs), Image.Resampling.LANCZOS)
            off = (px - cs) // 2
            im.paste(sc, (off, off), sc)
            im.save(os.path.join(macos_set_dir, fname), 'PNG')

    print("Successfully generated all launcher icons from aira_mascot_logo.png across Android, Web, Windows, iOS, and macOS!")

if __name__ == '__main__':
    create_icons()
