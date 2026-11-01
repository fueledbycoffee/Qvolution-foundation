#!/usr/bin/env python3
"""Fail unless source-built images provide the entire supplied demand manifest.

Pass each real re-export dependency as another --image. This is static coverage,
not a runtime load test; never use it to inspect Apple or guest-app binaries.
"""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--nm', required=True)
parser.add_argument('--manifest', type=Path, required=True)
parser.add_argument('--image', type=Path, action='append', required=True)
parser.add_argument('--control', type=Path, required=True)
parser.add_argument('--report', type=Path, required=True)
args = parser.parse_args()
names = set(args.manifest.read_text().splitlines())
if not names or any(not name.startswith('_') for name in names):
    parser.error('expected a nonempty Mach-O demand-name manifest')


def exports(image):
    output = subprocess.check_output(
        [args.nm, '--defined-only', '--extern-only', str(image)], text=True)
    return {line.split()[-1] for line in output.splitlines() if len(line.split()) > 1}


provided = set().union(*(exports(image) for image in args.image))
wrong = sorted(names & exports(args.control))
missing = sorted(names - provided)
report = {'kind': 'static-full-manifest', 'runtime': 'not verified',
          'manifest': str(args.manifest), 'images': [str(p) for p in args.image],
          'demanded': len(names), 'provided': len(names - set(missing)),
          'missing': missing, 'negative_control_matches': wrong,
          'passed': not missing and not wrong}
args.report.write_text(json.dumps(report, indent=2) + '\n')
print(f"{report['provided']}/{len(names)} provided; {len(missing)} missing; "
      f"negative control {len(wrong)}")
raise SystemExit(0 if report['passed'] else 1)
