# File-handle channel regressions

Run from this repository (Linux clang and libobjc):

    python3 tests/run-filehandle-native.py --out /absolute/output/path
    python3 tests/run-filehandle-native.py --source-ref c55eb6b --out /absolute/before/path

The runner extracts unedited production availableData, _monitor, notification
perform callback, dispatch-data conversion, and the read-to-end dispatch callback.
Linux pipes and read errors are real. Foundation values, dispatch ownership/events
and CF run-loop calls are controlled doubles. Blocks execute inline while their
stack frame remains valid. This fixture does not verify block-copy lifetime,
concurrency, dispatch readiness, or run-loop delivery in the guest.

Eight cases cover nonempty payloads, repeated EOF, signed read errors, real NSData
notification payloads, error-result cleanup, zero-byte readiness, source/queue
ownership through repeated cancellation, and completion with nil/empty final data.
On c55eb6b, the payload control passes and the other seven cases fail. All eight
pass after the fix. Guest validation remains the unchanged oracle-services
pipe-filehandle check: five payloads across three asynchronous public APIs.

Contracts: rung 3 Apple FileHandle documentation for availableData,
readInBackgroundAndNotify, readToEndOfFileInBackgroundAndNotify and
readabilityHandler; rung 1 swift-corelibs-foundation FileHandle.swift; rung 4
20261106T231133Z-checks_-84474/mac/pipe-filehandle.txt on macOS 12.7.6.
Exact URLs and verification commands are recorded in the commit body.
