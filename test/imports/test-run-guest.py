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
options, remaining = parser.parse_known_args()


class HostGuardTests(unittest.TestCase):
    def exercise(self, mode):
        work = options.scratch.resolve() / secrets.token_hex(5)
        lane = work / 'parallel/imp-foundation'
        lane.mkdir(parents=True)
        runner = lane / 'run-guest.py'
        shutil.copy2(options.runner, runner)
        guard = work / 'dashboard/qv-host-guard'
        guard.parent.mkdir()
        shutil.copy2(options.guard, guard)
        home = work / 'home'
        for folder in ('Documents', 'Desktop', 'Downloads', 'Movies', 'Music', 'Pictures'):
            (home / folder).mkdir(parents=True)
        root = lane / 'private-install/usr/local/libexec/darling'
        root.mkdir(parents=True)
        record = {'root': str(root), 'commits': {'foundation': 'test', 'swift': 'test'},
                  'payload_sha256': {}}
        (lane / 'prepared-private.json').write_text(json.dumps(record))
        payloads = ['native-build/load-exports',
                    'superproject/src/external/foundation/test/imports/exports.txt',
                    'swift/tests/darwin-foundation-imports/exports.txt',
                    'swift/tests/foundation-imports/exports.txt']
        for name in payloads:
            file = lane / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text('authored test fixture\n')
        launcher = work / 'parallel/stage41/build/src/startup/darling'
        launcher.parent.mkdir(parents=True)
        launcher.write_text('''#!/usr/bin/python3
import os, sys
from pathlib import Path
prefix = Path(os.environ['DPREFIX'])
mode = os.environ['TEST_MODE']
if sys.argv[1:] == ['shell', '/usr/bin/true']:
    assert not prefix.exists(), 'runner pre-created prefix'
    (prefix / 'tmp').mkdir(parents=True)
    (prefix / 'initialized').write_text('yes')
elif sys.argv[1] == 'shutdown':
    if mode == 'shutdown-write' and (prefix / 'tmp/imp-foundation').exists():
        (Path.home() / 'Pictures/guest-write').write_text('preserve me')
else:
    assert (prefix / 'initialized').exists()
    if mode in ('write', 'failed-write'):
        (Path.home() / 'Documents/guest-write').write_text('preserve me')
    if mode == 'failed-write': sys.exit(7)
''')
        launcher.chmod(0o755)
        def git_result(args, **kwargs):
            self.assertEqual(args[0], 'git')
            return 'test\n' if 'rev-parse' in args else ''
        with patch.dict(os.environ, HOME=str(home), TEST_MODE=mode), \
             patch.object(subprocess, 'check_output', side_effect=git_result), \
             patch.object(sys, 'argv', [str(runner)]), \
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


unittest.main(argv=[sys.argv[0], *remaining])
