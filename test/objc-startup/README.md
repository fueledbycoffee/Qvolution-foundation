# Normal Objective-C startup

Build `foundation_objc_startup` with `ENABLE_TESTS=ON` and the default
`DARLING_ENABLE_LEGACY_X86_SWIFT_FOUNDATION_OVERLAY=OFF` on x86_64. Run it under
a staged runtime in a dedicated prefix, with all `DYLD_*` environment overrides
removed, then shut down the prefix. The fixture rejects the flat-namespace and
insertion overrides explicitly, checks loaded image names through the public
dyld API, and performs a Unicode Foundation JSON round trip.

The parent fails before main: its Foundation re-export eagerly loads the Swift
5.2.2 x86_64 overlay against the Swift 6.3.3 core. The loader reports missing
`__swift_classIsSwiftMask`. The default stops forcing this incompatible overlay
into every Objective-C process; it does not implement Swift Foundation bindings.
The explicit legacy option preserves the old behavior for negative controls.
The arm64 re-export is unchanged. This x86_64 regression is not an arm64 test.

Provenance: vendored Foundation and dyld interfaces and existing build rules
(rung 2); version/provenance from darling-swift's README.md; loader errors and
source-built fixture results observed at the API boundary (rung 4). No Apple
binary inspection or modification, no new compatibility-symbol stubs.
