#!/usr/bin/env python3
"""Exercise the Windows C ABI on a POSIX host, including buffer capacity guards."""
import ctypes as c
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='mosaic-abi-') as tmp:
    library=Path(tmp)/'geometry.so'
    subprocess.run(['c++','-std=c++17','-O2','-ffp-contract=off','-shared','-fPIC',str(ROOT/'desktop/windows/native/GeometryC.cpp'),str(ROOT/'mobile/core/Geometry.cpp'),'-o',str(library)],check=True)
    api=c.CDLL(str(library))
    api.mosaic_layout_field.argtypes=[c.c_int,c.c_int];api.mosaic_layout_field.restype=c.c_char_p
    api.mosaic_frame.argtypes=[c.c_char_p,c.c_int,c.c_double,c.c_double,c.c_double,c.POINTER(c.c_double),c.c_int]
    assert api.mosaic_layout_count()==36
    assert api.mosaic_layout_field(-1,0)==b''
    assert api.mosaic_frame(None,1,100,100,0,None,0)==-1
    cases=0
    for i in range(36):
        layout=api.mosaic_layout_field(i,0)
        assert api.mosaic_layout_field(i,2).decode('utf-8')
        for count in range(1,25):
            for w,h in [(3840,768),(3840,3840),(768,3840)]:
                n=api.mosaic_frame(layout,count,w,h,120,None,0)
                assert 1<n<10000
                small=(c.c_double*2)(91,92)
                assert api.mosaic_frame(layout,count,w,h,120,small,1)==n and list(small)==[91,92]
                values=(c.c_double*(n+1))();values[n]=99
                assert api.mosaic_frame(layout,count,w,h,120,values,n)==n and values[n]==99
                assert 0<=values[0]<=120  # packed header is the effective safe gap
                offset=1
                for _ in range(count):
                    vertices=int(values[offset]);assert vertices>=3;offset+=1+vertices*2
                assert offset==n
                cases+=1
    print(f'PASS: {cases} C ABI frames, UTF-8 catalog, invalid input and guarded buffers')
