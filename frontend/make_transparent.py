import sys
import os

try:
    from PIL import Image
except ImportError:
    print("Pillow library is not installed. Installing it now...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow"])
    from PIL import Image

def convert_to_transparent(input_path, output_path):
    print(f"Loading image from {input_path}...")
    img = Image.open(input_path).convert("RGBA")
    datas = img.getdata()

    new_data = []
    for item in datas:
        r, g, b, a = item
        
        # Calculate brightness (using the maximum of R, G, B)
        # This preserves the anti-aliasing of the white lines.
        brightness = max(r, g, b)
        
        # If it's very dark (the background), make it transparent
        if brightness < 45:
            new_data.append((0, 0, 0, 0))
        else:
            # Scale alpha based on brightness to preserve antialiasing
            # Map brightness [45, 255] to alpha [0, 255]
            alpha = int((brightness - 45) * 255 / (255 - 45))
            alpha = max(0, min(255, alpha))
            
            # Make the non-transparent pixels crisp white to match the stark white theme
            new_data.append((255, 255, 255, alpha))

    # Save full version
    img.putdata(new_data)
    img.save(output_path, "PNG")
    print(f"Success! Transparent logo saved at {output_path}")

    # Crop and save just the icon (symbol) version
    width, height = img.size
    # Crop the top 76% of the image where the symbol sits
    icon_box = (0, 0, width, int(height * 0.76))
    icon_img = img.crop(icon_box)
    
    # Optional: trim empty space to make it perfectly centered and tight
    bbox = icon_img.getbbox()
    if bbox:
        # Pad the bounding box slightly to prevent clipping the outer lines
        pad = 20
        x0 = max(0, bbox[0] - pad)
        y0 = max(0, bbox[1] - pad)
        x1 = min(width, bbox[2] + pad)
        y1 = min(int(height * 0.76), bbox[3] + pad)
        
        # Make it a square bounding box for best layout consistency
        w = x1 - x0
        h = y1 - y0
        if w > h:
            y0 = max(0, y0 - (w - h)//2)
            y1 = min(int(height * 0.76), y1 + (w - h)//2)
        else:
            x0 = max(0, x0 - (h - w)//2)
            x1 = min(width, x1 + (h - w)//2)
            
        icon_img = icon_img.crop((x0, y0, x1, y1))
        
    icon_output_path = output_path.replace("transparent.png", "icon.png")
    icon_img.save(icon_output_path, "PNG")
    print(f"Success! Transparent icon saved at {icon_output_path}")

if __name__ == "__main__":
    src = "logo_premium.png"
    dest = "logo_premium_transparent.png"
    if os.path.exists(src):
        convert_to_transparent(src, dest)
    else:
        print(f"Error: {src} not found.")
