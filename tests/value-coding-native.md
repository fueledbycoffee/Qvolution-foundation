# NSValue coding and nil comparison

Run from the Foundation clone under `dashboard/qv-slot build`:

```
python3 tests/value-coding-native.py --case equality
python3 tests/value-coding-native.py --case coding
python3 tests/value-coding-native.py --source-ref 3558902 --case equality
python3 tests/value-coding-native.py --source-ref a2400ec --case coding
```

The two baseline commands fail: concrete equality passes NULL to strcmp, and
range initialization incorrectly uses the generic unkeyed decoder and returns
nil. The fixed commands pass 7 equality and 122 coding assertions with ASan/UBSan.

The fixture extracts production methods verbatim. Explicit host doubles replace
storage allocation/cache, type-size parsing, string geometry conversion, reference
counting and keyed storage. It exercises shared NSValue factory decoding, range
fields at unsigned boundaries, generic integer values, exact-sized copying,
short-payload rejection, typed geometry decoding and equality. The repeated range
cases mirror both supplied archive settings; the fixture does not emulate secure
unarchiver policy or archive bytes. Use the actual unarchiver policy native suite
for policy and the unchanged NSCoder+NSValue+NSRange.m qv-diff check for the full
runtime/wire-format gate. No Apple archive interoperability is inferred from the
Darling-local generic typed-value keys.
