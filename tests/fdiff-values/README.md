# Native differential regressions

Run under the host build slot:

```
python3 tests/fdiff-values/run-native.py --foundation a2400ec --corefoundation f51d51d --expect-failure --output /absolute/lane/native-before
python3 tests/fdiff-values/run-native.py --output /absolute/lane/native-after
```

The runner reads the selected revisions from this Foundation clone and its sibling
`corefoundation` clone. `WORKTREE` is available for development. Each section must
exit 1 before, and 0 after. The fixtures compile production JSON parser/validation,
Decimal math, KVC methods, ICU regex methods, Base64 decoding and selected value,
formatter, predicate, index shifting and CF bridge methods.
Index setup uses a bounded test backend; 5,103 small index-set shift cases
exercise the complete production shifting method, before and after. The actual
production addIndexes: and removeAllIndexes methods are included, so expansion
into per-index insertion cannot be hidden by a range-enumerating double. Dense
and 4,096-fragment cases assert zero individual insertions and insertion searches,
with at most one shift allocation per output range. Allocation failure and
overflow after partial output construction must leave the original set intact.
ReviewEdges.m preserves the reviewer public-API reproducer, including its
unrelated baseline Base64 facts. IndexShiftRanges.m adds public compressed ranges
of 10,000 and one billion indexes, fragmented ranges, cache reuse, range merging
and empty-result checks for qv-diff-batch. Native cache/lifetime remain doubles.

Storage, retain/release, class allocation, scanner failure and formatter range
parsing are explicit test doubles. The scanner double always fails to isolate
NSDecimalNumber's failure handling; exact decimal arithmetic/formatting use the
production implementation. The formatter double isolates the whole-input and
existing decimal-mode delegation paths. Synchronous stack blocks have a minimal
test-only runtime. The baseline formatter's dictionary subscript notation is
lowered to the equivalent objectForKey: message for GNU libobjc; other method
bodies are unchanged. A forward declaration is added for a later JSON function.

These tests do not establish guest runtime ABI, CF storage/lifetime, Unicode
collation, locale data or Apple/Darling agreement. Run the authored macOS checks
using the lane's run-qvdiff.sh after reviewing the commits. Existing public KVC
regressions tests/kvc-unions.m and tests/kvc-nil-values.m should also be run in the
guest. The lane's NSValue-size-oracle.m asks about unobserved buffer error cases.

R11 follow-up: the ordinary CF-number unsigned conversion expectation is corrected
from -1 to the full unsigned magnitude. macOS 12.7.6 distinguishes constant
integer literals from factory numbers (g11-foundation-4/oracle/
20261107T152939Z-constant-numbers.m_.txt). The literal path has separate production
method coverage in tests/constant-number-native.py. Sized NSValue extraction
also checks rejection of buffer sizes 0..8 except the exact int size.
