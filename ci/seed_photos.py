#!/usr/bin/env python3
"""Makes JPEGs with real capture dates and GPS at stadiums, for the simulator's
photo library, so the Discovery E2E test has something true to find."""
import os, sys, glob
from datetime import datetime, timedelta
from PIL import Image
import piexif

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "seed-photos")
os.makedirs(OUT, exist_ok=True)

def asset(name):
    return glob.glob(os.path.join(ROOT, "Witness", "Assets.xcassets", "Photos", f"{name}.imageset", "*.jp*g"))[0]

# (photo, local time, utc offset, lat, lon)
SHOTS = [
    # Fenway, an evening game not in a fresh library
    ("fenway-night", "2017-06-09 19:22", "-04:00", 42.3467, -71.0972),
    ("fenway-day", "2017-06-09 20:40", "-04:00", 42.3465, -71.0975),
    ("fenway-postcard", "2017-06-09 21:55", "-04:00", 42.3469, -71.0969),
    # Wrigley, World Series Game 5 night
    ("wrigley-night", "2016-10-30 19:02", "-05:00", 41.9484, -87.6553),
    ("wrigley-scoreboard", "2016-10-30 20:34", "-05:00", 41.9486, -87.6556),
    ("wrigley-night-2", "2016-10-30 22:42", "-05:00", 41.9482, -87.6550),
    ("wrigley-bleachers", "2016-10-30 22:43", "-05:00", 41.9489, -87.6549),
    # Not at a stadium: must not match
    ("soldier-skyline", "2019-05-01 12:00", "-05:00", 41.8827, -87.6233),
]

def dms(value):
    value = abs(value)
    d = int(value); m = int((value - d) * 60); s = round(((value - d) * 60 - m) * 60 * 100)
    return ((d, 1), (m, 1), (s, 100))

# A scoreboard photo with a date but no GPS: Stanley Cup Final Game 6, United Center, June 15 2015.
# Album import has to find the game from the board itself.
from PIL import ImageDraw, ImageFont
board = Image.new("RGB", (1600, 1000), (12, 12, 16))
d = ImageDraw.Draw(board)
try:
    big, small = ImageFont.load_default(size=200), ImageFont.load_default(size=90)
except TypeError:
    big = small = ImageFont.load_default()
d.text((120, 120), "TB    0", font=big, fill=(255, 214, 80))
d.text((120, 420), "CHI   2", font=big, fill=(255, 214, 80))
d.text((1000, 780), "FINAL", font=small, fill=(255, 255, 255))
stamp = b"2015:06:15 21:40:00"
board_exif = {"0th": {piexif.ImageIFD.DateTime: stamp},
              "Exif": {piexif.ExifIFD.DateTimeOriginal: stamp, piexif.ExifIFD.OffsetTimeOriginal: b"-05:00"}}
board.save(os.path.join(OUT, "seed-90-scoreboard-nogps.jpg"), "JPEG", quality=90, exif=piexif.dump(board_exif))

for i, (name, local, offset, lat, lon) in enumerate(SHOTS):
    img = Image.open(asset(name)).convert("RGB")
    img.thumbnail((1600, 1600))
    stamp = datetime.strptime(local, "%Y-%m-%d %H:%M").strftime("%Y:%m:%d %H:%M:%S").encode()
    exif = {
        "0th": {piexif.ImageIFD.Make: b"Apple", piexif.ImageIFD.Model: b"iPhone", piexif.ImageIFD.DateTime: stamp},
        "Exif": {piexif.ExifIFD.DateTimeOriginal: stamp, piexif.ExifIFD.DateTimeDigitized: stamp,
                 piexif.ExifIFD.OffsetTimeOriginal: offset.encode(), piexif.ExifIFD.OffsetTime: offset.encode()},
        "GPS": {piexif.GPSIFD.GPSLatitudeRef: b"N" if lat >= 0 else b"S", piexif.GPSIFD.GPSLatitude: dms(lat),
                piexif.GPSIFD.GPSLongitudeRef: b"E" if lon >= 0 else b"W", piexif.GPSIFD.GPSLongitude: dms(lon)},
    }
    path = os.path.join(OUT, f"seed-{i:02d}-{name}.jpg")
    img.save(path, "JPEG", quality=85, exif=piexif.dump(exif))
    print(path)
