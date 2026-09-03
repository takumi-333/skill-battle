"""集中状態用の単純な円形ドットパーティクルを機械生成する。"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


SIZE = 8
PARTICLE_SIZES = {"small": 1.5, "medium": 2.25, "large": 3.1}
PALETTES = {
    "typist": {
        "deep_green": (30, 92, 61, 255),
        "green": (70, 166, 93, 255),
        "gold": (216, 181, 91, 255),
    },
    "chanter": {
        "deep_purple": (72, 43, 104, 255),
        "purple": (143, 78, 173, 255),
        "pale_pink": (255, 151, 190, 255),
        "gold": (216, 181, 91, 255),
    },
    "arithmetic": {
        "deep_navy": (28, 39, 78, 255),
        "blue_white": (176, 224, 255, 255),
        "gold": (216, 181, 91, 255),
    },
}


def make_particle(color: tuple[int, int, int, int], radius: float, variant: int) -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pixels = image.load()
    center = 3.5 + ((variant % 3) - 1) * 0.18
    for y in range(SIZE):
        for x in range(SIZE):
            distance = ((x - center) ** 2 + (y - center) ** 2) ** 0.5
            if distance <= radius:
                # 少しだけ欠けを作り、完全な円だけにならないようにする。
                if variant % 4 == 1 and x == 1 and y == 3:
                    continue
                if variant % 4 == 2 and x == 6 and y == 4:
                    continue
                if variant % 4 == 3 and y == 1 and x == 4:
                    continue
                pixels[x, y] = color
    return image


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=Path("assets/effects/focus_particles"))
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    count = 0
    for character, colors in PALETTES.items():
        for color_index, (color_name, color) in enumerate(colors.items()):
            for size_name, radius in PARTICLE_SIZES.items():
                image = make_particle(color, radius, color_index)
                output = args.output_dir / f"{character}_{color_name}_{size_name}.png"
                image.save(output)
                count += 1
    print(f"generated {count} focus particle PNGs in {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
