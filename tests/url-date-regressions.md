URL/calendar regressions, round 2 (2026-11-03, fdiff-url-date).

`url-date-api.m` exercises the real public API. It retains all URL round trips,
escaping, Unicode/plus and nil/empty query-item assertions. It adds Havana's
repeated midnight (2015-11-01), Sao Paulo's skipped midnight (2018-11-04),
23/25-hour New York calendar-day additions, January 31 month-end clamping, and
property/numeric undefined/explicit-INT_MAX round trips. Explicit INT_MAX is
separate from undefined only on the 64-bit ABI.

`url-date-native.py` compiles the production Foundation methods AND the real
CoreFoundation NSDateComponents storage and calendar component-vector helper.
Calendar primitives still use host ICU doubles; URL calls use forwarding doubles.
The decoded query/fragment doubles accept nil as the real CF setters do; encoded
path rejection remains asserted. `corefoundation/tests/day-boundary-native.py`
adapts the reviewer's reproducer and compiles the unedited production
__CFCalendarSetToFirstInstant helper with host ICU. It also checks that wall-time
attributes are restored. Neither fixture establishes full guest backend behavior.

Verified in this lane (commands run through dashboard/qv-slot build):

```
python3 foundation/tests/url-date-native.py --review-before
# Old production storage/category: components abort (-6), URL/calendar pass.
# explicit INT_MAX nanosecond: numeric=9223372036854775807 valid=1
# clear day: property=2147483647 numeric=9223372036854775807
python3 foundation/tests/url-date-native.py
# All groups pass, including the production CF vector boundary.
# explicit INT_MAX nanosecond: numeric=2147483647 valid=0
# clear day: property=numeric=9223372036854775807
python3 corefoundation/tests/day-boundary-native.py --before
# Havana second midnight=1446354000, executable exits 2 as expected.
python3 corefoundation/tests/day-boundary-native.py
# Havana first midnight=1446350400; Sao Paulo first instant=1541300400; exit 0.
ninja -C parallel/fdiff-url-date/build -j6
# Complete CoreFoundation AND Foundation payloads link i386/x86_64; universal merges pass.
ninja -C parallel/fdiff-url-date/build -f public.ninja -j6
# Public regression links i386/x86_64 and merges.
ninja -C parallel/fdiff-url-date/build -n
ninja -C parallel/fdiff-url-date/build -f public.ninja -n
# Both report no work remaining.
```

Evidence: native-review-before-r2.log, native-after-r2.log,
native/{day-before,day-after}/cf-day.log, build/build-r2-retry.log,
build/public-r2.log. The failed initial full CF link remains in build/build-r2.log:
Clang -### escapes `$` in Objective-C alias names; the lane replay helper now
removes that shell escape when converting the printed command to an argv array.
No source or linker symbols were changed to suppress the failure.

Requires BOTH the CoreFoundation undefined-storage correction and Foundation's
removal of the INT_MAX conversion. Calendar vector construction now omits the
public NSInteger sentinel. Catalyst a557861's source/header replace the overlapping
dc89224 implementation exactly; regression fixtures remain. Integration must omit
dc89224 and its revert 20eaf17, and use Catalyst a557861 (lane cherry-pick 3eb6123).

The sandbox cannot boot Darling or invoke the Mac oracle. Both original checks
remain unchanged: NSURL+NSURLComponents.m and
NSDateFormatter+NSCalendar+NSDateComponents.m. The refreshed lane run-qvdiff.sh
installs both frameworks into its private runtime with broken destination hardlinks.
Default mode verifies pinned inputs and exercises all preparation with no Mac/guest.
The exact live gate is QV_RUN=1 parallel/fdiff-url-date/run-qvdiff.sh. New MATCH
results are not claimed until that command runs. The runner also executes the
extended public regression, fails initialization/host-guard errors, and uses only
its exact fresh prefix and pinned non-setuid launcher.

Existing quarter/leap-month backend limitations remain outside these corrections;
no stub is introduced. Sources: rung 2 production CF storage/vector/helper; rung 3
Apple startOfDay and numeric component documentation; rung 1 Swift Foundation's
NSInteger-sized undefined constant. Exact URLs are in implementation commit bodies
and lane REFERENCES.md. No forbidden material was encountered.
