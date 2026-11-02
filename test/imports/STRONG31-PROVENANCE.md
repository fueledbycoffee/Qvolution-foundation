# Strong Foundation residuals

Source stack: imp-foundation r3-r6 (foundation 8d621d1; swift 25116c1).
Native dependencies: Stage41c3 superproject 8aff919e94, cocotron a360e4d95.
No Apple implementation binaries, quarantined headers or tainted trees were read.

The unchanged strong Foundation gate contains 755 names. The residual fixture
contains the 31 names identified by the authorized prior missing-import run
(rung 5 supplies names only). The full runner also retains the 658-name Swift
Foundation manifest and the two-name DarwinFoundation1 manifest.

Specifications and implementation sources:

- JSON5: rung 1, swift-foundation dbacc677 JSONDecoder.swift/JSON5Scanner.swift
  and FoundationEssentialsTests/Resources/JSON5/spec. Native tests exercise the
  actual parser and Float unboxing body with Linux collection/accessor spelling.
- Checked I/O: rung 2, NSFileHandle.h, existing descriptor implementation and
  POSIX read/write declarations. Errors preserve errno; closed handles fail.
- String transforms: rung 2, CFStringTransform; rung 1, the published CF
  diacritic-transform identifier. Mapping the NSString alias is GUESS.
- Run-loop scheduling: rung 2, CFRunLoop/NSTimer declarations. Arithmetic is
  adapted from MIT OpenCombine 10df981 (license retained in the Swift repo).
  Notification and scheduler Combine behavior is GUESS, not an Apple-source port.
- URL.FormatStyle component/default policies, bookmark ENOTSUP policy, the
  extension entry signature and failure return, presentation-key spelling,
  WebSocket message interface/enum values, relative-formatter interface/enums,
  component rounding and archive keys are GUESS (rung 6).

Bookmarks/alias formats and the extension-host lifecycle are unavailable.
These operations report failure. The WebSocket class represents a message value;
this change does not implement a WebSocket transport. URL.FormatStyle supplies
the demanded scheme-display surface, not every newer formatting modifier.
Relative formatting uses ICU and requires guest validation of calendar boundaries.

Exact reproduction and evidence are under parallel/foundation-strong-31 in the
fleet workspace. Build: dashboard/qv-slot build ninja -C that-lane -j6, then
ninja -C that-lane -n. check-exports.py audits only our source-built images.
The native JSON5 corpus, numeric values, Float special values, URL formatting
and unavailable extension entry have independent native fixtures.

Container validation is not performed in this sandbox. run-container.sh requires
an orchestrator-allocated lane Stage41c3 install; it never creates a full stage
copy. It installs only committed outputs under a build slot, then holds one guest
slot, initializes a fresh short prefix before staging fixtures, clears inherited
DYLD variables, uses qv-shutdown and verifies the host-folder snapshot afterward.
