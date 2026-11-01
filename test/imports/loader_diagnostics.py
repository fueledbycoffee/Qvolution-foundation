"""Explain the authored export fixture's failures without changing its status."""
import re

DARWIN_FOUNDATION = '/usr/lib/swift/libswift_DarwinFoundation1.dylib'


def classify_loader_output(text):
    exports = re.findall(r'^missing (\S+) in ([^:\n]+):', text, re.MULTILINE)
    images = sorted(set(re.findall(r'^dlopen ([^:\n]+):[^\n]*image not found', text, re.MULTILINE)))
    dependencies = []
    for image in images:
        dependency = {'image': image}
        if image == DARWIN_FOUNDATION:
            dependency.update(provider_lane='swift-in-stage', integration_stage='Stage41d',
                              action='integrate the source-built overlay from swift-in-stage into Stage41d and rerun')
        dependencies.append(dependency)
    counts = {}
    for _, image in exports:
        counts[image] = counts.get(image, 0) + 1
    return {'state': 'dependency_missing' if dependencies else ('exports_missing' if exports else 'no_loader_diagnostic'),
            'missing_images': dependencies, 'missing_export_count': len(exports),
            'missing_exports_by_image': counts}


def gate_outcome(comparison, strong, diagnostics):
    if any(item['missing_images'] for item in diagnostics):
        return 'needs_review'
    return 'gate_passed' if strong else ('partial' if comparison else 'failed')
