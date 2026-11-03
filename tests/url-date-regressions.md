The missing URL component accessors and calendar convenience methods are covered
by `url-date-api.m` (the real public API) and `url-date-native.py` (a focused Linux
libobjc/ICU fixture). The latter compiles production methods without rewriting
them. URL backend functions are doubles: decoding and serialization must also be
checked against the real CF backend in the guest. Calendar range and arithmetic
primitives use an ICU double, so this native test does not prove Darling's DST
implementation. NSDateComponents storage is a double with the CF cluster's
existing INT_MAX representation.

Verified 2026-11-03 in lane fdiff-url-date:

```
qv-slot build python3 foundation/tests/url-date-native.py --before
# url, calendar, components each exit -6 at the missing-selector assertion;
# the regression driver passes because baseline failure is required.
qv-slot build python3 foundation/tests/url-date-native.py
# url, calendar, components each exit 0; driver passes.
qv-slot build ninja -C parallel/fdiff-url-date/build -j6
ninja -C parallel/fdiff-url-date/build -n
# complete i386/x86_64 Foundation links and universal merge pass; no work remains.
qv-slot build ninja -C parallel/fdiff-url-date/build -f public.ninja -j6
# public API regression compiles and links for i386/x86_64.
```

The sandbox cannot boot Darling. Unchanged oracle checks
`NSURL+NSURLComponents.m` and `NSDateFormatter+NSCalendar+NSDateComponents.m`
remain the live gate. `parallel/fdiff-url-date/run-qvdiff.sh` prepares a pinned
private runtime; its default dry run exercises preparation without the Mac or a
guest. An orchestrator executes `QV_RUN=1 .../run-qvdiff.sh` to run both unchanged
checks plus `url-date-api.m` on macOS and Darling. This runner uses a local guarded
version of dashboard/qv-diff: the shared version ignores initialization failure,
does not stop between initialization and copying, and ignores host-guard failure.

Scope limits: primitive NSDateComponents property getters still expose their old
INT_MAX unset storage on 64-bit; the new numeric dispatch translates it. Quarter
composition/decomposition and leap-month support in the existing CF backend are
not repaired by these convenience APIs. No new backend stub is introduced.

Rung 4 source: `parallel/oracle-foundation/BATCH1-RESULTS.md`, authored checks on
macOS 12.7.6 and Stage41g (29 URL, 24 calendar differences). Rungs 1–3 and exact
URLs are recorded in the implementation commit bodies and lane REFERENCES.md.
