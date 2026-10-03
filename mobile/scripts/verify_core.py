#!/usr/bin/env python3
"""Compile real mobile geometry and compare all layouts/counts with the web engine."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="mosaic-core-") as directory:
    binary = str(Path(directory) / "geometry")
    subprocess.run([os.environ.get("CXX", "c++"), "-std=c++17", "-O2", "-ffp-contract=off", "-Wall", "-Wextra", "-Werror",
                    str(root / "mobile/core/Geometry.cpp"), str(root / "mobile/core/GeometryCLI.cpp"), "-o", binary], check=True)
    reference = subprocess.run(["node", str(root / "mobile/scripts/export-reference.mjs")], capture_output=True, text=True, check=True)
    cases = [json.loads(line) for line in reference.stdout.splitlines()]
    request = "".join(f"{c['id']} {c['n']} {c['w']:.17g} {c['h']:.17g} {c['gap']}\n" for c in cases)
    result = subprocess.run([binary], input=request, text=True, capture_output=True, check=True)
    lines = result.stdout.splitlines()
    assert len(lines) == len(cases)
    for case, line in zip(cases, lines):
        actual = list(map(float, line.split()))
        expected = case['expected']
        label = {k: v for k, v in case.items() if k != 'expected'}
        assert len(actual) == len(expected), f"Cell/vertex count mismatch: {label}"
        assert all(abs(a-b) < 1e-6 for a,b in zip(actual, expected)), f"Geometry mismatch: {label}"
    print(f"PASS: {len(cases):,} native/web comparisons (36 layouts × 24 counts × 7 ratios × 3 borders)")
