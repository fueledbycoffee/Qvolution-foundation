#!/usr/bin/env python3
"""Native runner regression: the launcher is authored Python, never Darling."""
import argparse
import contextlib
import io
import json
import os
from pathlib import Path
import runpy
import secrets
import shutil
import subprocess
import sys
import unittest
from unittest.mock import patch

parser = argparse.ArgumentParser()
parser.add_argument('--runner', type=Path, required=True)
parser.add_argument('--guard', type=Path, required=True)
parser.add_argument('--scratch', type=Path, required=True)
parser.add_argument('--shutdown', type=Path, required=True)
options, remaining = parser.parse_known_args()


class HostGuardTests(unittest.TestCase):
    def exercise(self, mode, flags=()):
        work = options.scratch.resolve() / secrets.token_hex(5)
        lane = work / 'parallel/imp-foundation'
        lane.mkdir(parents=True)
        runner = lane / 'run-guest.py'
        shutil.copy2(options.runner, runner)
        guard = work / 'dashboard/qv-host-guard'
        guard.parent.mkdir()
        shutil.copy2(options.guard, guard)
        shutil.copy2(options.shutdown, guard.with_name('qv-shutdown'))
        # Exercise the real retry helper without sleeping in native unit tests.
        bin_dir = work / 'bin'
        bin_dir.mkdir()
        sleeper = bin_dir / 'sleep'
        sleeper.write_text('#!/bin/sh\nexit 0\n')
        sleeper.chmod(0o755)
        if mode == 'snapshot-fail':
            guard.write_text('#!/usr/bin/python3\nimport sys\nsys.exit(2)\n')
        home = work / 'home'
        for folder in ('Documents', 'Desktop', 'Downloads', 'Movies', 'Music', 'Pictures'):
            (home / folder).mkdir(parents=True)
        root = lane / 'private-install/usr/local/libexec/darling'
        root.mkdir(parents=True)
        (work / 'stage41b/usr/local/libexec/darling').mkdir(parents=True)
        record = {'root': str(root), 'commits': {'foundation': 'test', 'swift': 'test'},
                  'payload_sha256': {}}
        (lane / 'prepared-private.json').write_text(json.dumps(record))
        payloads = ['native-build/load-exports',
                    'superproject/src/external/foundation/test/imports/exports.txt',
                    'superproject/src/external/foundation/test/imports/strong-exports.txt',
                    'swift/tests/darwin-foundation-imports/exports.txt',
                    'swift/tests/foundation-imports/exports.txt']
        for name in payloads:
            file = lane / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text('full strong fixture\n' if file.name == 'strong-exports.txt' else 'authored test fixture\n')
        launcher = work / 'parallel/stage41/build/src/startup/darling'
        launcher.parent.mkdir(parents=True)
        launcher.write_text(r'''#!/usr/bin/python3
import os, sys
from pathlib import Path
prefix = Path(os.environ['DPREFIX'])
mode = os.environ['TEST_MODE']
if sys.argv[1:] == ['shell', '/usr/bin/true']:
    assert not prefix.exists(), 'runner pre-created prefix'
    (prefix / 'Applications').mkdir(parents=True)
    (prefix / 'tmp').symlink_to('/qv-test-missing-tmp')
    (prefix / 'initialized').write_text('yes')
elif sys.argv[1] == 'shutdown':
    if mode == 'shutdown-fail': sys.exit(1)
    if mode == 'shutdown-retry':
        marker = prefix / 'shutdown-pending'
        if not marker.exists():
            marker.write_text('retry needed')
            sys.exit(1)
        marker.unlink()
    if mode == 'shutdown-write' and (prefix / 'Applications/imp-foundation').exists():
        (Path.home() / 'Pictures/guest-write').write_text('preserve me')
else:
    assert (prefix / 'initialized').exists()
    assert sys.argv[2] == '/Applications/imp-foundation/load-exports'
    assert (prefix / 'Applications/imp-foundation/load-exports').is_file()
    if mode == 'full-strong':
        assert (prefix / 'Applications/imp-foundation/Foundation.txt').read_text() == 'full strong fixture\n'
    if mode in ('write', 'failed-write'):
        (Path.home() / 'Documents/guest-write').write_text('preserve me')
    if mode == 'failed-write': sys.exit(7)
''')
        launcher.chmod(0o755)
        def git_result(args, **kwargs):
            self.assertEqual(args[0], 'git')
            return 'test\n' if 'rev-parse' in args else ''
        with patch.dict(os.environ, HOME=str(home), TEST_MODE=mode, PATH=str(bin_dir) + os.pathsep + os.environ['PATH']), \
             patch.object(subprocess, 'check_output', side_effect=git_result), \
             patch.object(sys, 'argv', [str(runner), *flags]), \
             contextlib.redirect_stdout(io.StringIO()):
            try:
                runpy.run_path(str(runner), run_name='__main__')
            except SystemExit as error:
                code = error.code
            else:
                code = 0
        result = json.loads(next((lane / 'guest-runs').glob('*/result.json')).read_text())
        return code, result, home

    def test_clean_run(self):
        code, result, _ = self.exercise('clean')
        self.assertEqual(code, 0)
        self.assertTrue(result['dlopen_test_passed'])
        self.assertEqual(result['host_guard']['verify'], 0)

    def test_shutdown_retries_after_init_and_fixture(self):
        code, result, _ = self.exercise('shutdown-retry')
        self.assertEqual(code, 0)
        self.assertTrue(result['dlopen_test_passed'])

    def test_shutdown_exhaustion_fails_and_still_guards(self):
        code, result, _ = self.exercise('shutdown-fail')
        self.assertNotEqual(code, 0)
        self.assertFalse(result['dlopen_test_passed'])
        self.assertEqual(result['host_guard']['verify'], 0)

    def test_successful_fixture_cannot_hide_host_write(self):
        code, result, home = self.exercise('write')
        self.assertEqual(code, 3)
        self.assertFalse(result['dlopen_test_passed'])
        self.assertEqual(result['outcome'], 'failed')
        self.assertEqual(result['host_guard']['verify'], 3)
        self.assertTrue((home / 'Documents/guest-write').exists())

    def test_failed_fixture_still_verifies(self):
        code, result, _ = self.exercise('failed-write')
        self.assertEqual(code, 3)
        self.assertEqual(result['host_guard']['verify'], 3)

    def test_guard_covers_final_shutdown(self):
        code, result, home = self.exercise('shutdown-write')
        self.assertEqual(code, 3)
        self.assertEqual(result['host_guard']['verify'], 3)
        self.assertTrue((home / 'Pictures/guest-write').exists())

    def test_snapshot_failure_never_launches(self):
        code, result, _ = self.exercise('snapshot-fail')
        self.assertNotEqual(code, 0)
        self.assertEqual(result['steps'], [])
        self.assertEqual(result['host_guard'], {'snapshot': 2, 'verify': None})

    def test_baseline_selects_source_built_stage41b(self):
        code, result, _ = self.exercise('baseline', ['--baseline'])
        self.assertEqual(code, 0)
        self.assertTrue(result['baseline'])
        self.assertTrue(result['runtime_root'].endswith('/stage41b/usr/local/libexec/darling'))

    def test_full_gate_copies_the_full_manifest(self):
        code, result, _ = self.exercise('full-strong', ['--full-strong'])
        self.assertEqual(code, 0)
        self.assertEqual(result['scope'], 'all strong imports')


unittest.main(argv=[sys.argv[0], *remaining])
