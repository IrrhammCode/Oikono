import os
from PIL import Image

def process_logo(input_path, output_path):
    print(f"Opening input image: {input_path}")
    img = Image.open(input_path)
    w, h = img.size
    
    # Step 1: Detect background color (from corners)
    corners = [img.getpixel((0,0)), img.getpixel((w-1,0)), img.getpixel((0,h-1)), img.getpixel((w-1,h-1))]
    bg_r = sum(c[0] for c in corners) // 4
    bg_g = sum(c[1] for c in corners) // 4
    bg_b = sum(c[2] for c in corners) // 4
    print(f"Detected background color: ({bg_r}, {bg_g}, {bg_b})")
    
    # Step 2: Find bounding box of non-background pixels
    pixels = img.load()
    non_bg = []
    threshold = 30
    
    for x in range(w):
        for y in range(h):
            r, g, b = pixels[x, y]
            dist = abs(r - bg_r) + abs(g - bg_g) + abs(b - bg_b)
            if dist > threshold:
                non_bg.append((x, y))
                
    if not non_bg:
        print("Error: Could not find any logo foreground pixels!")
        return False
        
    xs = [p[0] for p in non_bg]
    ys = [p[1] for p in non_bg]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    
    logo_w = max_x - min_x
    logo_h = max_y - min_y
    print(f"Detected logo bounding box: x=({min_x}, {max_x}), y=({min_y}, {max_y}) (Size: {logo_w}x{logo_h})")
    
    # Step 3: Expand to a square crop with padding
    padding = 30
    
    # Determine square size (maximum dimension + padding)
    square_size = max(logo_w, logo_h) + (padding * 2)
    
    # Calculate center of the bounding box
    center_x = min_x + logo_w // 2
    center_y = min_y + logo_h // 2
    
    # Calculate crop coordinates
    crop_x0 = max(0, center_x - square_size // 2)
    crop_y0 = max(0, center_y - square_size // 2)
    crop_x1 = min(w, crop_x0 + square_size)
    crop_y1 = min(h, crop_y0 + square_size)
    
    # Adjust in case crop went out of bounds
    if crop_x1 - crop_x0 < square_size:
        if crop_x0 == 0:
            crop_x1 = min(w, square_size)
        elif crop_x1 == w:
            crop_x0 = max(0, w - square_size)
            
    if crop_y1 - crop_y0 < square_size:
        if crop_y0 == 0:
            crop_y1 = min(h, square_size)
        elif crop_y1 == h:
            crop_y0 = max(0, h - square_size)
            
    print(f"Cropping square image at: ({crop_x0}, {crop_y0}, {crop_x1}, {crop_y1})")
    cropped_img = img.crop((crop_x0, crop_y0, crop_x1, crop_y1))
    
    # Step 4: Make background transparent and preserve white foreground antialiasing
    cropped_img = cropped_img.convert("RGBA")
    c_w, c_h = cropped_img.size
    c_pixels = cropped_img.load()
    
    new_data = []
    for y in range(c_h):
        for x in range(c_w):
            r, g, b, a = c_pixels[x, y]
            
            # Brightness based on maximum channel
            val = max(r, g, b)
            
            # Map background (around 42) to transparent, and foreground (up to 255) to opaque
            if val <= bg_r + 5:
                # Fully transparent background
                new_data.append((0, 0, 0, 0))
            else:
                # Smooth alpha interpolation
                alpha = int((val - bg_r) * 255 / (255 - bg_r))
                alpha = max(0, min(255, alpha))
                # Set color to pure white with calculated alpha for nice smooth anti-aliased look
                new_data.append((255, 255, 255, alpha))
                
    # Save the processed image
    transparent_img = Image.new("RGBA", (c_w, c_h))
    transparent_img.putdata(new_data)
    transparent_img.save(output_path, "PNG")
    print(f"Success! Saved beautiful transparent logo to: {output_path}")
    return True

if __name__ == "__main__":
    process_logo("logo.jpg", "logo.png")
