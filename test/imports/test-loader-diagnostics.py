#!/usr/bin/env python3
"""Native tests for actionable gate failures; no Darling boot."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('loader_diagnostics', Path(__file__).with_name('loader_diagnostics.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class LoaderDiagnosticsTests(unittest.TestCase):
    def test_missing_swift_image_names_stage_dependency(self):
        result = module.classify_loader_output('missing _known in /Foundation: symbol not found\n'
            'dlopen /usr/lib/swift/libswift_DarwinFoundation1.dylib: image not found\n')
        self.assertEqual(result['missing_export_count'], 1)
        dependency, = result['missing_images']
        self.assertEqual(dependency['provider_lane'], 'swift-in-stage')
        self.assertEqual(dependency['integration_stage'], 'Stage41d')
        self.assertEqual(result['state'], 'dependency_missing')
        self.assertEqual(module.gate_outcome(True, True, [result]), 'needs_review')

    def test_exports_are_distinct_from_a_missing_image(self):
        result = module.classify_loader_output('missing _one in /Foundation: symbol not found\n'
            'missing _two in /Foundation: symbol not found\nexports checked=1415 failures=1\n')
        self.assertEqual(result['missing_export_count'], 2)
        self.assertEqual(result['missing_images'], [])
        self.assertEqual(result['state'], 'exports_missing')
        self.assertEqual(module.gate_outcome(True, False, [result]), 'partial')

    def test_unknown_dependency_is_not_assigned_a_provider(self):
        result = module.classify_loader_output('dlopen /unknown.dylib: image not found\n')
        self.assertEqual(result['missing_images'], [{'image': '/unknown.dylib'}])

    def test_no_diagnostics_does_not_turn_a_failed_command_green(self):
        result = module.classify_loader_output('other failure\n')
        self.assertEqual(module.gate_outcome(False, False, [result]), 'failed')
        self.assertEqual(module.gate_outcome(True, True, [result]), 'gate_passed')

if __name__ == '__main__':
    unittest.main()
