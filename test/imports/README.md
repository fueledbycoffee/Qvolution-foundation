This fixture loads the explicit source-built library paths passed on its command
line. For each library it reads a manifest of audit-demanded Mach-O names and
calls dlsym (without the Mach-O leading underscore). Missing names, dlopen errors,
empty manifests and an unexpectedly present negative control fail the test.

Build foundation_import_exports with ENABLE_TESTS=ON, or compile load-exports.c
against Darling's source-built libSystem, then run it in a private matching Swift
runtime:

    load-exports /System/Library/Frameworks/Foundation.framework/Versions/C/Foundation exports.txt

exports.txt covers the audit names provided by the real matching Swift 6.3.3
Foundation overlay plus NSMultipleUnderlyingErrorsKey. It is not an API-completeness
claim. Remaining audit imports are explicitly reported by the fleet lane.

Use DARLING_MATCHING_X86_SWIFT_FOUNDATION_OVERLAY to point CMake at the rebuilt
libswiftFoundation.dylib. The framework re-exports that library under its normal
/usr/lib/swift install name, so a complete matching Swift runtime must be selected
in the private configured install. Re-exporting the Swift 5.2.2 binary with Swift
6.3.3 is unsafe and remains disabled by default. This option does not install the
overlay or its dependencies; deployment must select the whole matching set.

Rung 1 sources: Darling's overlays/Foundation and Swift public overlay sources,
plus swift-foundation dbacc67779dc0a41ddc9493acbaa332d76c9fb03 (Apache-2.0).
CocoaError.swift underlyingErrors uses the NSMultipleUnderlyingErrorsKey string
verbatim. No undocumented string value or hand-authored Swift ABI stub is used.

The fleet's maintained container runner is run-guest.py. Set QV_FOUNDATION_LANE
explicitly to the prepared lane directory and invoke it while holding one guest
slot. It requires dashboard/qv-host-guard in the fleet work area, snapshots before
any launcher call, and verifies after final shutdown, including fixture failures.
Host changes make the run fail (exit 3); guest-written files are preserved.
Run the native regression with an authored fake launcher (no container):

    python3 test/imports/test-run-guest.py --runner test/imports/run-guest.py \
        --guard /path/to/dashboard/qv-host-guard --scratch /tmp/if-runner-tests

The scratch path must be short enough for the runner's 83-byte prefix limit.

strong-exports.txt is the complete set of 755 non-weak Foundation imports from
this lane's imports-sweep-a/b demand audit. Unlike exports.txt, it includes the
unimplemented imports. check-strong-exports.py exits nonzero for every gap and
requires an unrelated source-built negative control in the same invocation.
review-error-resource-exports.txt isolates the ten error/resource imports ported
in the fix round. All names are rung 5 demand facts; availability is not inferred
from mangled spellings and no Swift ABI is manufactured to satisfy them.
