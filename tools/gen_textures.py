#!/usr/bin/env python3
"""Procedural textures for Mimi's Magical World (soft cartoon look)."""
import math
import random
from PIL import Image, ImageDraw, ImageFilter

OUT = "/home/hatch/workspace/mimis-magical-world/textures"
import os
os.makedirs(OUT, exist_ok=True)
random.seed(42)


def wood(path, base, dark, light, planks=8, size=1024):
    img = Image.new("RGB", (size, size), base)
    d = ImageDraw.Draw(img, "RGBA")
    ph = size // planks
    for p in range(planks):
        y0 = p * ph
        tint = random.randint(-10, 10)
        d.rectangle([0, y0, size, y0 + ph], fill=(base[0] + tint, base[1] + tint, base[2] + tint, 255))
        # grain: wavy horizontal strokes
        for _ in range(46):
            gy = y0 + random.randint(3, ph - 3)
            gx = random.randint(-40, size - 160)
            ln = random.randint(90, 260)
            col = dark if random.random() < 0.6 else light
            alpha = random.randint(18, 46)
            pts = [(gx + t, gy + math.sin(t * 0.05 + p) * 1.6) for t in range(0, ln, 14)]
            d.line(pts, fill=col + (alpha,), width=random.randint(1, 3))
        # a knot now and then
        if random.random() < 0.55:
            kx, ky = random.randint(80, size - 80), y0 + ph // 2
            for r in range(9, 1, -2):
                d.ellipse([kx - r * 2, ky - r, kx + r * 2, ky + r], outline=dark + (70,), width=2)
        d.line([0, y0, size, y0], fill=(60, 38, 22, 160), width=3)
        # plank end seams
        sx = random.randint(60, size - 60)
        d.line([sx, y0, sx, y0 + ph], fill=(60, 38, 22, 120), width=3)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(path)


def grass(path, size=1024):
    img = Image.new("RGB", (size, size), (84, 158, 66))
    d = ImageDraw.Draw(img, "RGBA")
    # soft darker/lighter patches
    for _ in range(60):
        x, y = random.randint(0, size), random.randint(0, size)
        r = random.randint(40, 130)
        col = (58, 128, 48, 26) if random.random() < 0.5 else (120, 190, 96, 22)
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)
    img = img.filter(ImageFilter.GaussianBlur(6))
    d = ImageDraw.Draw(img, "RGBA")
    # thousands of little blades
    greens = [(66, 138, 52), (96, 176, 74), (120, 196, 96), (50, 118, 44), (140, 208, 110)]
    for _ in range(15000):
        x, y = random.randint(0, size), random.randint(0, size)
        h = random.randint(4, 10)
        c = random.choice(greens)
        d.line([x, y, x + random.randint(-2, 2), y - h], fill=c + (200,), width=1)
    img.save(path)


def tile(path, size=768, grid=6):
    img = Image.new("RGB", (size, size), (168, 190, 178))
    d = ImageDraw.Draw(img, "RGBA")
    t = size // grid
    cols = [(206, 232, 218), (198, 226, 224), (214, 236, 226), (202, 230, 214)]
    for i in range(grid):
        for j in range(grid):
            c = random.choice(cols)
            d.rectangle([i * t + 3, j * t + 3, (i + 1) * t - 3, (j + 1) * t - 3], fill=c + (255,))
            for _ in range(26):
                x, y = random.randint(i * t + 4, (i + 1) * t - 4), random.randint(j * t + 4, (j + 1) * t - 4)
                d.point((x, y), fill=(255, 255, 255, 60))
    img.save(path)


def rug(path, size=768):
    img = Image.new("RGB", (size, size), (244, 168, 184))
    d = ImageDraw.Draw(img)
    cx = size // 2
    rings = [(244, 168, 184), (252, 214, 224), (240, 140, 166), (252, 228, 234), (246, 178, 192)]
    r = cx
    for i, c in enumerate(rings):
        d.ellipse([cx - r, cx - r, cx + r, cx + r], fill=c)
        r -= size // 11
    # dotted ring decoration
    import math as m
    for k in range(28):
        a = 2 * m.pi * k / 28
        x, y = cx + m.cos(a) * size * 0.335, cx + m.sin(a) * size * 0.335
        d.ellipse([x - 9, y - 9, x + 9, y + 9], fill=(255, 240, 246))
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    img.save(path)


def fabric(path, base, size=512):
    img = Image.new("RGB", (size, size), base)
    d = ImageDraw.Draw(img, "RGBA")
    for y in range(0, size, 3):
        d.line([0, y, size, y], fill=(0, 0, 0, 10), width=1)
    for x in range(0, size, 3):
        d.line([x, 0, x, size], fill=(255, 255, 255, 8), width=1)
    for _ in range(5000):
        x, y = random.randint(0, size), random.randint(0, size)
        d.point((x, y), fill=(0, 0, 0, 22) if random.random() < 0.5 else (255, 255, 255, 20))
    img.save(path)


wood(f"{OUT}/wood.png", (176, 128, 84), (120, 82, 48), (214, 168, 118))
wood(f"{OUT}/wood_pink.png", (186, 138, 152), (138, 96, 110), (222, 178, 190))
grass(f"{OUT}/grass.png")
tile(f"{OUT}/tile.png")
rug(f"{OUT}/rug.png")
fabric(f"{OUT}/fabric_pink.png", (238, 148, 176))
print("textures done:", os.listdir(OUT))
