# NSValue production-method regression

Run `python3 tests/value-coding-native.py --case equality` and `--case coding`.
Both fail against rolling baseline 3685eda (pass `--source-ref 3685eda`): nil
comparison reaches strcmp(NULL), and range construction returns nil.

The fixture extracts production methods unchanged and runs with ASan/UBSan.
Host adapters replace allocation, type parsing, reference counting, sequential
coder storage and geometry conversion. Cases cover unsigned range boundaries,
generic integer coding, copy/equality, exact-sized buffers and typed geometry.
The repeated range cases mirror both supplied archive settings but do not
simulate secure validation or archive parsing. Run the public API differential
checks to verify those real integration paths and the archive wire format.
