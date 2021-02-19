#!/usr/bin/python
"""
Given a zoom level, prints tile x/y for set lat/lon to terminal
Use:

python3 latlon_xy_conversion.py <zoom int>
"""
import sys
import math

def convert_latlon(lat_deg, lon_deg, zoom):
    lat_rad = math.radians(lat_deg)
    n = 2.0 ** zoom
    xtile = int((lon_deg + 180.0) / 360.0 * n)
    ytile = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)
    return (xtile, ytile)

if __name__ == '__main__':

    # set to Ohio, takes a zoom from user
    lat = 39.685
    lon = -83.705
    zoom = int(sys.argv[1])
    tile = convert_latlon(lat, lon, zoom)
    print(tile)