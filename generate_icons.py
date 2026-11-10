import os
import json
import shutil
from PIL import Image, ImageDraw

def create_icons():
    project_root = os.path.dirname(os.path.abspath(__file__))
    if os.path.basename(project_root) == 'scripts':
        repo_root = os.path.dirname(project_root)
    else:
        repo_root = project_root

    mascot_path = os.path.join(repo_root, 'airamp_flutter', 'assets', 'images', 'aira_mascot_logo.png')
    brand_logo_path = os.path.join(repo_root, 'airamp_flutter', 'assets', 'images', 'aira_logo.png')

    if not os.path.exists(brand_logo_path):
        brand_logo_path = os.path.join(repo_root, 'logo', 'aira_logo.png')

    if not os.path.exists(brand_logo_path):
        raise FileNotFoundError(f"Brand logo ('a' logo) not found at {brand_logo_path}")

    # Palette
    bg_color = (10, 20, 32, 255)       # #0A1420
    bg_color_rgb = (10, 20, 32)

    # =========================================================================
    # 1. MOBILE APPS (Android & iOS): Use the peeking mascot holding the border
    # =========================================================================
    if os.path.exists(mascot_path):
        print("1. Generating Mobile App Icons (Peeking Mascot holding border)...")
        mascot_raw = Image.open(mascot_path).convert('RGBA')

        # Detect artwork bounding box (filter out alpha noise < 15)
        a_channel = mascot_raw.split()[3]
        thresh = a_channel.point(lambda p: 255 if p > 15 else 0)
        bbox = thresh.getbbox()
        cropped_mascot = mascot_raw.crop(bbox) if bbox else mascot_raw
        cw, ch = cropped_mascot.size

        # Android resources
        res_dir = os.path.join(repo_root, 'airamp_flutter', 'android', 'app', 'src', 'main', 'res')
        densities = {
            'mipmap-mdpi': (48, 108),
            'mipmap-hdpi': (72, 162),
            'mipmap-xhdpi': (96, 216),
            'mipmap-xxhdpi': (144, 324),
            'mipmap-xxxhdpi': (192, 432),
        }

        for folder, (icon_size, fg_size) in densities.items():
            folder_path = os.path.join(res_dir, folder)
            os.makedirs(folder_path, exist_ok=True)

            # 1a. Legacy ic_launcher.png & ic_launcher_round.png
            target_h = int(icon_size * 0.90)
            target_w = int(cw * (target_h / ch))
            scaled_legacy = cropped_mascot.resize((target_w, target_h), Image.Resampling.LANCZOS)
            
            # Align right edge flush with the circle edge
            right_x = icon_size - 2
            left_x = right_x - target_w
            top_y = (icon_size - target_h) // 2

            # Circle badge legacy
            legacy = Image.new('RGBA', (icon_size, icon_size), (0, 0, 0, 0))
            draw = ImageDraw.Draw(legacy)
            draw.ellipse([1, 1, icon_size - 2, icon_size - 2], fill=bg_color)
            legacy.paste(scaled_legacy, (left_x, top_y), scaled_legacy)
            legacy.save(os.path.join(folder_path, 'ic_launcher.png'), 'PNG')

            # Round icon
            round_icon = Image.new('RGBA', (icon_size, icon_size), (0, 0, 0, 0))
            r_draw = ImageDraw.Draw(round_icon)
            r_draw.ellipse([0, 0, icon_size - 1, icon_size - 1], fill=bg_color)
            round_icon.paste(scaled_legacy, (left_x, top_y), scaled_legacy)
            round_icon.save(os.path.join(folder_path, 'ic_launcher_round.png'), 'PNG')

            # 1b. Adaptive icon foreground (ic_launcher_foreground.png)
            # Safe zone viewport in 108dp canvas is 18dp..90dp.
            # Aligning right edge to 90dp - 1px puts her hands directly on the squircle/circle right border!
            fg = Image.new('RGBA', (fg_size, fg_size), (0, 0, 0, 0))
            fg_target_h = int(fg_size * (72 / 108) * 0.94)
            fg_target_w = int(cw * (fg_target_h / ch))
            scaled_fg = cropped_mascot.resize((fg_target_w, fg_target_h), Image.Resampling.LANCZOS)
            
            fg_right_x = int(fg_size * (90 / 108)) - 1
            fg_left_x = fg_right_x - fg_target_w
            fg_top_y = (fg_size - fg_target_h) // 2

            fg.paste(scaled_fg, (fg_left_x, fg_top_y), scaled_fg)
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

        # iOS App Icons (Mobile App)
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

                im = Image.new('RGB', (px, px), bg_color_rgb)
                t_h = int(px * 0.90)
                if t_h < 1:
                    t_h = 1
                t_w = int(cw * (t_h / ch))
                if t_w < 1:
                    t_w = 1
                sc = cropped_mascot.resize((t_w, t_h), Image.Resampling.LANCZOS)
                r_x = px - 2
                l_x = max(0, r_x - t_w)
                t_y = (px - t_h) // 2
                im.paste(sc, (l_x, t_y), sc)
                im.save(os.path.join(ios_set_dir, fname), 'PNG')

        print("   -> Mobile app icons successfully generated with peeking mascot!")
    else:
        print("   -> Warning: aira_mascot_logo.png not found, skipping mobile app mascot icons.")

    # =========================================================================
    # 2. WEB & DESKTOP: Use the official Brand "a" Logo (aira_logo.png)
    # =========================================================================
    print("2. Generating Web & Desktop Icons (Official 'a' Brand Logo)...")
    brand_logo = Image.open(brand_logo_path).convert('RGBA')

    # Web icons directory
    web_icons_dir = os.path.join(repo_root, 'airamp_flutter', 'web', 'icons')
    os.makedirs(web_icons_dir, exist_ok=True)

    # 2a. Web PWA Icons (192, 512)
    for size, name in [(192, 'Icon-192.png'), (512, 'Icon-512.png')]:
        web_im = Image.new('RGBA', (size, size), bg_color)
        content_size = int(size * 0.88)
        scaled = brand_logo.resize((content_size, content_size), Image.Resampling.LANCZOS)
        offset = (size - content_size) // 2
        web_im.paste(scaled, (offset, offset), scaled)
        web_im.save(os.path.join(web_icons_dir, name), 'PNG')

    # 2b. Web Maskable Icons (192, 512)
    for size, name in [(192, 'Icon-maskable-192.png'), (512, 'Icon-maskable-512.png')]:
        web_im = Image.new('RGBA', (size, size), bg_color)
        content_size = int(size * 0.76)
        scaled = brand_logo.resize((content_size, content_size), Image.Resampling.LANCZOS)
        offset = (size - content_size) // 2
        web_im.paste(scaled, (offset, offset), scaled)
        web_im.save(os.path.join(web_icons_dir, name), 'PNG')

    # 2c. Web Favicon (64x64)
    fav = Image.new('RGBA', (64, 64), bg_color)
    content_size = int(64 * 0.90)
    scaled = brand_logo.resize((content_size, content_size), Image.Resampling.LANCZOS)
    offset = (64 - content_size) // 2
    fav.paste(scaled, (offset, offset), scaled)
    web_fav_path = os.path.join(repo_root, 'airamp_flutter', 'web', 'favicon.png')
    fav.save(web_fav_path, 'PNG')

    # 2d. Sync directly to build/web so running web server updates immediately
    build_web_dir = os.path.join(repo_root, 'airamp_flutter', 'build', 'web')
    if os.path.exists(build_web_dir):
        print("   -> Syncing brand 'a' logo to build/web (favicon & icons)...")
        shutil.copy2(web_fav_path, os.path.join(build_web_dir, 'favicon.png'))
        build_web_icons = os.path.join(build_web_dir, 'icons')
        if os.path.exists(build_web_icons):
            for item in os.listdir(web_icons_dir):
                src_item = os.path.join(web_icons_dir, item)
                dst_item = os.path.join(build_web_icons, item)
                if os.path.isfile(src_item):
                    shutil.copy2(src_item, dst_item)

    # 2e. Windows ICO (Desktop)
    win_res_dir = os.path.join(repo_root, 'airamp_flutter', 'windows', 'runner', 'resources')
    if os.path.exists(win_res_dir):
        ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
        ico_images = []
        for s in ico_sizes:
            im = Image.new('RGBA', s, bg_color)
            cs = int(s[0] * 0.88)
            sc = brand_logo.resize((cs, cs), Image.Resampling.LANCZOS)
            off = (s[0] - cs) // 2
            im.paste(sc, (off, off), sc)
            ico_images.append(im)
        ico_images[0].save(os.path.join(win_res_dir, 'app_icon.ico'), format='ICO', sizes=ico_sizes)

    # 2f. macOS (Desktop)
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
            cs = int(px * 0.76)
            if cs < 1:
                cs = 1
            sc = brand_logo.resize((cs, cs), Image.Resampling.LANCZOS)
            off = (px - cs) // 2
            im.paste(sc, (off, off), sc)
            im.save(os.path.join(macos_set_dir, fname), 'PNG')

    print("   -> Web & Desktop icons successfully restored to official 'a' Brand Logo!")
    print("\nAll done!")

if __name__ == '__main__':
    create_icons()
