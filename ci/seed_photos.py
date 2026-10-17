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
    ("fenway-night", "2017-06-03 19:12", "-04:00", 42.3467, -71.0972),
    ("fenway-day", "2017-06-03 20:40", "-04:00", 42.3465, -71.0975),
    ("fenway-postcard", "2017-06-03 21:55", "-04:00", 42.3469, -71.0969),
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
