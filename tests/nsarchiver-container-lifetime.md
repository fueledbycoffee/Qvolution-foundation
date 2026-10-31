# Unkeyed container ownership

Build `nsarchiver-container-lifetime.m` as an Objective-C executable linked
to Foundation with manual reference counting. Run it separately with the
`dictionary` and `array` arguments against the candidate runtime. Each must
print `PASS decoded container owns child through pool drain and releases it once`
and exit zero. The test retains the decoded container across a pool drain,
checks a decoded child deallocation counter without dereferencing a potentially
dangling graph, then checks that releasing the container destroys the child once.

The original dictionary input failed on stage27 (Foundation cbde81c88373):
`decodedDeaths=1` after the pool drained while the container remained held,
exit 1. The unchanged array control passed, exit 0. This is a public API
observation from an authored NSCoding token, not a retainCount assertion.
The committed regression is the original diagnostic source, unchanged.
Candidate runtime execution remains required; a translation-unit compilation
does not demonstrate that ownership or image roundtrips now pass.
