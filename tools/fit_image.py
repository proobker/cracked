"""Scale and centre-crop an image to exact Play Console dimensions.

    python tools/fit_image.py <in> <out.png> <width> <height>

The image is scaled to cover the target, then cropped from the centre, and
saved as a 24-bit PNG (Play rejects transparency in feature graphics).
"""
import sys

from PIL import Image


def main() -> None:
    src, dst, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    img = Image.open(src).convert("RGB")
    scale = max(w / img.width, h / img.height)
    img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    left, top = (img.width - w) // 2, (img.height - h) // 2
    img.crop((left, top, left + w, top + h)).save(dst)
    print(f"  wrote {dst} ({w}x{h})")


if __name__ == "__main__":
    main()
