#!/usr/bin/env python3
"""Container host only: compare the identical fixture on baseline and candidate."""
import argparse
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys


def infrastructure_ok(result):
    steps = {step['step']: step['returncode'] for step in result['steps']}
    return (result['host_guard'] == {'snapshot': 0, 'verify': 0}
            and (steps.get('initialize') == 0 or steps.get('initialize-retry') == 0)
            and steps.get('initial-shutdown') == 0
            and steps.get('final-shutdown') == 0
            and 'dlopen-all-exports' in steps)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lane', type=Path, required=True)
    args = parser.parse_args()
    lane = args.lane.resolve()
    work = lane.parent.parent
    log = lane / 'acceptance-runs' / secrets.token_hex(4)
    log.mkdir(parents=True, exist_ok=False)
    cases = [('baseline', ['--baseline']), ('candidate', []),
             ('candidate-full-strong', ['--full-strong'])]
    results = {}
    for name, flags in cases:
        command = [str(work / 'dashboard/qv-slot'), 'guest', sys.executable,
                   str(lane / 'run-guest.py'), *flags]
        env = dict(os.environ, QV_FOUNDATION_LANE=str(lane))
        with (log / f'{name}.log').open('x') as output:
            proc = subprocess.run(command, env=env, stdout=output, stderr=subprocess.STDOUT)
        lines = (log / f'{name}.log').read_text().splitlines()
        # The maintained runner prints its result directory after guarded shutdown.
        path = Path(lines[-1]) / 'result.json' if lines else Path('/nonexistent')
        if not path.is_file():
            results[name] = {'returncode': proc.returncode, 'error': 'runner produced no result'}
            break
        result = json.loads(path.read_text())
        results[name] = {'returncode': proc.returncode, 'result': str(path), 'run': result}
        if not infrastructure_ok(result):
            break
    comparison = False
    strong = False
    if 'candidate-full-strong' in results:
        before = results['baseline']['run']
        after = results['candidate']['run']
        full = results['candidate-full-strong']['run']
        same = (before['fixture_sha256'] == after['fixture_sha256'] == full['fixture_sha256']
                and before['manifest_sha256'] == after['manifest_sha256'])
        comparison = (same and all(infrastructure_ok(r['run']) for r in results.values())
                      and results['baseline']['returncode'] == 1
                      and results['candidate']['returncode'] == 0)
        strong = comparison and results['candidate-full-strong']['returncode'] == 0
    outcome = 'gate_passed' if strong else ('partial' if comparison else 'failed')
    report = {'outcome': outcome, 'baseline_candidate_subset_passed': comparison,
              'full_strong_gate_passed': strong, 'cases': results}
    (log / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print(log / 'result.json')
    return 0 if strong else 1


if __name__ == '__main__':
    sys.exit(main())
