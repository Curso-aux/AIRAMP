import os
from PIL import Image, ImageDraw

def create_icons():
    # Source image: assets/images/aira_logo.png
    project_root = os.path.dirname(os.path.abspath(__file__))
    # Handle if run from repo root or scripts dir
    if os.path.basename(project_root) == 'scripts':
        repo_root = os.path.dirname(project_root)
    else:
        repo_root = project_root

    logo_path = os.path.join(repo_root, 'airamp_flutter', 'assets', 'images', 'aira_logo.png')
    if not os.path.exists(logo_path):
        logo_path = os.path.join(repo_root, 'logo', 'aira_logo.png')
    
    if not os.path.exists(logo_path):
        raise FileNotFoundError(f"Source logo not found at {logo_path}")

    logo = Image.open(logo_path).convert('RGBA')

    # Background color: Deep navy #0A1420 matching AppTheme.darkBackground
    bg_color = (10, 20, 32, 255)

    res_dir = os.path.join(repo_root, 'airamp_flutter', 'android', 'app', 'src', 'main', 'res')
    
    # Mipmap densities: (legacy_icon_size, adaptive_fg_size)
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

        # 1. Legacy ic_launcher.png
        legacy = Image.new('RGBA', (icon_size, icon_size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(legacy)
        draw.ellipse([1, 1, icon_size - 2, icon_size - 2], fill=bg_color)
        
        inner_size = int(icon_size * 0.90)
        scaled_logo = logo.resize((inner_size, inner_size), Image.Resampling.LANCZOS)
        offset = (icon_size - inner_size) // 2
        legacy.paste(scaled_logo, (offset, offset), scaled_logo)
        legacy.save(os.path.join(folder_path, 'ic_launcher.png'), 'PNG')

        # 2. Round ic_launcher_round.png
        round_icon = Image.new('RGBA', (icon_size, icon_size), (0, 0, 0, 0))
        r_draw = ImageDraw.Draw(round_icon)
        r_draw.ellipse([0, 0, icon_size - 1, icon_size - 1], fill=bg_color)
        round_icon.paste(scaled_logo, (offset, offset), scaled_logo)
        round_icon.save(os.path.join(folder_path, 'ic_launcher_round.png'), 'PNG')

        # 3. Adaptive icon foreground ic_launcher_foreground.png
        # Scaled to 76% so the crest and character are prominent and fill the adaptive mask perfectly
        fg = Image.new('RGBA', (fg_size, fg_size), (0, 0, 0, 0))
        fg_content_size = int(fg_size * 0.76)
        scaled_fg_logo = logo.resize((fg_content_size, fg_content_size), Image.Resampling.LANCZOS)
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

    # Web icons
    web_icons_dir = os.path.join(repo_root, 'airamp_flutter', 'web', 'icons')
    os.makedirs(web_icons_dir, exist_ok=True)
    for size, name in [(192, 'Icon-192.png'), (512, 'Icon-512.png')]:
        web_im = Image.new('RGBA', (size, size), bg_color)
        content_size = int(size * 0.88)
        scaled = logo.resize((content_size, content_size), Image.Resampling.LANCZOS)
        offset = (size - content_size) // 2
        web_im.paste(scaled, (offset, offset), scaled)
        web_im.save(os.path.join(web_icons_dir, name), 'PNG')

    for size, name in [(192, 'Icon-maskable-192.png'), (512, 'Icon-maskable-512.png')]:
        web_im = Image.new('RGBA', (size, size), bg_color)
        content_size = int(size * 0.76)
        scaled = logo.resize((content_size, content_size), Image.Resampling.LANCZOS)
        offset = (size - content_size) // 2
        web_im.paste(scaled, (offset, offset), scaled)
        web_im.save(os.path.join(web_icons_dir, name), 'PNG')

    # Web favicon
    fav = Image.new('RGBA', (64, 64), bg_color)
    content_size = int(64 * 0.90)
    scaled = logo.resize((content_size, content_size), Image.Resampling.LANCZOS)
    offset = (64 - content_size) // 2
    fav.paste(scaled, (offset, offset), scaled)
    fav.save(os.path.join(repo_root, 'airamp_flutter', 'web', 'favicon.png'), 'PNG')

    # Windows ICO
    win_res_dir = os.path.join(repo_root, 'airamp_flutter', 'windows', 'runner', 'resources')
    if os.path.exists(win_res_dir):
        ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
        ico_images = []
        for s in ico_sizes:
            im = Image.new('RGBA', s, bg_color)
            cs = int(s[0] * 0.90)
            sc = logo.resize((cs, cs), Image.Resampling.LANCZOS)
            off = (s[0] - cs) // 2
            im.paste(sc, (off, off), sc)
            ico_images.append(im)
        ico_images[0].save(os.path.join(win_res_dir, 'app_icon.ico'), format='ICO', sizes=ico_sizes)

    print("Successfully generated all launcher icons from aira_logo.png!")

if __name__ == '__main__':
    create_icons()
