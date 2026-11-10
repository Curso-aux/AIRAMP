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
    print(f"Generating peeking border-hugging icons from {source_name} (artwork: {cw}x{ch})...")

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

    # 1. Android Icons
    for folder, (icon_size, fg_size) in densities.items():
        folder_path = os.path.join(res_dir, folder)
        os.makedirs(folder_path, exist_ok=True)

        # 1a. Legacy ic_launcher.png & ic_launcher_round.png
        # The mascot is aligned to the right border of the circular badge so she grips the border
        target_h = int(icon_size * 0.90)
        scale = target_h / ch
        target_w = int(cw * scale)
        scaled_legacy = cropped.resize((target_w, target_h), Image.Resampling.LANCZOS)
        
        # Right edge aligns with circle edge (icon_size - 2)
        right_x = icon_size - 2
        left_x = right_x - target_w
        top_y = (icon_size - target_h) // 2

        # Legacy icon
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

        # 1c. Adaptive icon foreground ic_launcher_foreground.png
        # Android's safe mask viewport spans from 18dp to 90dp within the 108dp canvas.
        # Her hands are at vertical mid-height. Aligning right_x to 90dp puts her hands
        # directly on the squircle/circle right border, giving the peeking effect!
        fg = Image.new('RGBA', (fg_size, fg_size), (0, 0, 0, 0))
        fg_target_h = int(fg_size * (72 / 108) * 0.94)
        fg_scale = fg_target_h / ch
        fg_target_w = int(cw * fg_scale)
        scaled_fg = cropped.resize((fg_target_w, fg_target_h), Image.Resampling.LANCZOS)
        
        # 90dp border position (minus 1px so her fingers seamlessly grip the right border)
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

    # 2. Web icons
    web_icons_dir = os.path.join(repo_root, 'airamp_flutter', 'web', 'icons')
    os.makedirs(web_icons_dir, exist_ok=True)
    for size, name in [(192, 'Icon-192.png'), (512, 'Icon-512.png')]:
        web_im = Image.new('RGBA', (size, size), bg_color)
        t_h = int(size * 0.90)
        t_w = int(cw * (t_h / ch))
        scaled = cropped.resize((t_w, t_h), Image.Resampling.LANCZOS)
        r_x = size - 2
        l_x = r_x - t_w
        t_y = (size - t_h) // 2
        web_im.paste(scaled, (l_x, t_y), scaled)
        web_im.save(os.path.join(web_icons_dir, name), 'PNG')

    for size, name in [(192, 'Icon-maskable-192.png'), (512, 'Icon-maskable-512.png')]:
        web_im = Image.new('RGBA', (size, size), bg_color)
        t_h = int(size * (72 / 108) * 0.94)
        t_w = int(cw * (t_h / ch))
        scaled = cropped.resize((t_w, t_h), Image.Resampling.LANCZOS)
        r_x = int(size * (90 / 108)) - 1
        l_x = r_x - t_w
        t_y = (size - t_h) // 2
        web_im.paste(scaled, (l_x, t_y), scaled)
        web_im.save(os.path.join(web_icons_dir, name), 'PNG')

    # Web favicon
    fav = Image.new('RGBA', (64, 64), bg_color)
    t_h = int(64 * 0.90)
    t_w = int(cw * (t_h / ch))
    scaled = cropped.resize((t_w, t_h), Image.Resampling.LANCZOS)
    r_x = 64 - 2
    l_x = r_x - t_w
    t_y = (64 - t_h) // 2
    fav.paste(scaled, (l_x, t_y), scaled)
    fav.save(os.path.join(repo_root, 'airamp_flutter', 'web', 'favicon.png'), 'PNG')

    # 3. Windows ICO
    win_res_dir = os.path.join(repo_root, 'airamp_flutter', 'windows', 'runner', 'resources')
    if os.path.exists(win_res_dir):
        ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
        ico_images = []
        for s in ico_sizes:
            im = Image.new('RGBA', s, bg_color)
            t_h = int(s[0] * 0.90)
            if t_h < 1:
                t_h = 1
            t_w = int(cw * (t_h / ch))
            if t_w < 1:
                t_w = 1
            sc = cropped.resize((t_w, t_h), Image.Resampling.LANCZOS)
            r_x = s[0] - 1
            l_x = max(0, r_x - t_w)
            t_y = (s[0] - t_h) // 2
            im.paste(sc, (l_x, t_y), sc)
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
            t_h = int(px * 0.90)
            if t_h < 1:
                t_h = 1
            t_w = int(cw * (t_h / ch))
            if t_w < 1:
                t_w = 1
            sc = cropped.resize((t_w, t_h), Image.Resampling.LANCZOS)
            # iOS applies squircle corner radius of ~22%. Mid-height is flat edge, right at px - 2
            r_x = px - 2
            l_x = max(0, r_x - t_w)
            t_y = (px - t_h) // 2
            im.paste(sc, (l_x, t_y), sc)
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
            t_h = int(px * 0.88)
            if t_h < 1:
                t_h = 1
            t_w = int(cw * (t_h / ch))
            if t_w < 1:
                t_w = 1
            sc = cropped.resize((t_w, t_h), Image.Resampling.LANCZOS)
            r_x = px - 2
            l_x = max(0, r_x - t_w)
            t_y = (px - t_h) // 2
            im.paste(sc, (l_x, t_y), sc)
            im.save(os.path.join(macos_set_dir, fname), 'PNG')

    print("Successfully generated peeking border-hugging launcher icons across Android, Web, Windows, iOS, and macOS!")

if __name__ == '__main__':
    create_icons()
