#!/usr/bin/env python3
"""Generate every platform's icon from the same original geometric mark; stdlib only."""
from pathlib import Path
import json
import struct
import zlib

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
COLORS = {'background': '#18181b', 'frame': '#f6f1e4', 'gold': '#d79e56', 'sage': '#748d7f', 'clay': '#af7262'}
RECTS = [(0,0,1024,1024,'background'), (170,170,854,854,'frame'), (196,196,500,828,'gold'), (526,196,828,498,'sage'), (526,524,828,828,'clay')]

def png(size, desktop=False):
    pixels=[]
    for y in range(size):
        row=bytearray()
        for x in range(size):
            # Four samples per pixel retain readable edges at 16 and 32 px.
            samples=[]
            for dx,dy in [(0.25,0.25),(0.75,0.25),(0.25,0.75),(0.75,0.75)]:
                px=(x+dx)*1024/size; py=(y+dy)*1024/size
                alpha=255
                if desktop:
                    px=(px-64)*1024/896; py=(py-64)*1024/896
                    qx=max(170-px,0,px-854); qy=max(170-py,0,py-854)
                    if px<0 or py<0 or px>1024 or py>1024 or qx*qx+qy*qy>170*170: alpha=0
                color=COLORS['background']
                for l,t,r,b,key in RECTS:
                    if l<=px<r and t<=py<b: color=COLORS[key]
                samples.append([int(color[i:i+2],16) for i in (1,3,5)]+[alpha])
            row.extend(round(sum(s[c] for s in samples)/4) for c in range(4 if desktop else 3))
        pixels.append(b'\0'+row)
    def chunk(tag,data): return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',size,size,8,6 if desktop else 2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(pixels),9))+chunk(b'IEND',b'')

def write(path,data):
    path=ROOT/path; path.parent.mkdir(parents=True,exist_ok=True); path.write_bytes(data)

svg='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'+''.join(f'<rect x="{l}" y="{t}" width="{r-l}" height="{b-t}" fill="{COLORS[k]}"'+(' rx="210"' if k=='background' else '')+'/>' for l,t,r,b,k in RECTS)+'</svg>\n'
(HERE/'mosaic.svg').write_text(svg)
write(Path('dist/favicon.svg'),svg.encode())
write(Path('dist/apple-touch-icon.png'),png(180))
write(Path('mobile/ios/Mosaic/Assets.xcassets/AppIcon.appiconset/AppIcon.png'),png(1024))
# ICNS PNG representations, including Retina sizes.
parts=[]
for tag,size in [('icp4',16),('icp5',32),('icp6',64),('ic07',128),('ic08',256),('ic09',512),('ic10',1024)]:
    data=png(size,True); parts.append(tag.encode()+struct.pack('>I',len(data)+8)+data)
body=b''.join(parts); write(Path('desktop/macos/Mosaic/AppIcon.icns'),b'icns'+struct.pack('>I',len(body)+8)+body)
# Windows supports PNG-compressed entries inside ICO; include small taskbar sizes.
images=[(n,png(n,True)) for n in (16,24,32,48,64,128,256)]
header=struct.pack('<HHH',0,1,len(images)); directory=b''; offset=6+16*len(images)
for size,data in images:
    directory+=struct.pack('<BBBBHHII',size if size<256 else 0,size if size<256 else 0,0,0,1,32,len(data),offset); offset+=len(data)
write(Path('desktop/windows/Mosaic/AppIcon.ico'),header+directory+b''.join(data for _,data in images))
# Android foreground has the artwork wholly inside the adaptive-icon safe zone.
res=ROOT/'mobile/android/app/src/main/res'
(res/'drawable/ic_mosaic_foreground.xml').write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
<path android:fillColor="#f6f1e4" android:pathData="M30,30h48v48h-48z"/>
<path android:fillColor="#d79e56" android:pathData="M32,32h21v44h-21z"/>
<path android:fillColor="#748d7f" android:pathData="M55,32h21v21h-21z"/>
<path android:fillColor="#af7262" android:pathData="M55,55h21v21h-21z"/>
</vector>\n''')
(res/'drawable/ic_mosaic_monochrome.xml').write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
<path android:fillColor="#ffffff" android:pathData="M30,30h23v48h-23zM56,30h22v22h-22zM56,55h22v23h-22z"/>
</vector>\n''')
for folder,mono in [('mipmap-anydpi-v26',False),('mipmap-anydpi-v33',True)]:
    (res/folder).mkdir(exist_ok=True)
    (res/folder/'ic_launcher.xml').write_text('<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/icon_background"/><foreground android:drawable="@drawable/ic_mosaic_foreground"/>'+('<monochrome android:drawable="@drawable/ic_mosaic_monochrome"/>' if mono else '')+'</adaptive-icon>\n')
(res/'values').mkdir(exist_ok=True)
(res/'values/icon_colors.xml').write_text('<resources><color name="icon_background">#18181b</color></resources>\n')
print('Generated SVG, PNG, ICNS, ICO and Android adaptive/monochrome icons.')
