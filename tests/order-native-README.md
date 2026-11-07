# Native callback-order regressions
Run from any directory with Linux Clang, GNU libobjc and BlocksRuntime installed:

```
python3 tests/run-order-native.py --core-source /path/to/corefoundation --out /path/to/output
python3 tests/run-order-native.py --core-source /path/to/corefoundation --out /path/to/baseline-output --before
```

The runner extracts production regions verbatim from Foundation and CoreFoundation.
The baseline is Foundation c55eb6b and CoreFoundation 3f34c24 (frozen r6 inputs).
Each baseline section must abort at an assertion; each patched section must pass.
Sections cover configured notification centers, FIFO/coalescing masks, modes,
cancellation, queue disposal, nested delivery, both observer-removal forms,
repeated object joins, nested KVO with multiple and removed observers, and
finite-deadline rounding. Storage/runtime/scheduling controls isolate these
algorithms; they do not establish actual guest run-loop scheduling or MATCH.
The unchanged oracle-order checks provide that separate integration gate.
