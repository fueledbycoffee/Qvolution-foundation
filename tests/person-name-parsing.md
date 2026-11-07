Latin person-name parsing
=========================

Contract (rung 3):
https://developer.apple.com/tutorials/data/documentation/foundation/personnamecomponentsformatter/personnamecomponents(from:).json
specifies inferred component roles, compound components, inversion, capitalization
preservation and ignored annotations. The implementation is an independent heuristic;
these rules do not uniquely determine every person's intended name components.

Behavioral observations (rung 4): macOS 12.7.6, locale en_US. Lane
`g11-foundation2-2/parser-probe.m` and `parser-probe-extra.m` vary given names,
surnames, component counts, case and comma placement. Outputs are retained in
`oracle/20261107T160330Z-parser-probe.m_.txt` and
`oracle/20261107T160623Z-parser-probe-extra.m_.txt`. These establish the compound
lexemes in givenNameLength and the test expectations. The tests include every
input from reviewer `rev-g11-b/person-contract.m`, preserved unchanged as
`person-name-review.m`.

Independent population data (supporting rung 6 heuristic, not an Apple spec):
https://www2.census.gov/topics/genealogy/1990surnames/dist.male.first
https://www2.census.gov/topics/genealogy/1990surnames/dist.female.first
https://www2.census.gov/topics/genealogy/1990surnames/dist.all.last

These are US federal Census 1990 name frequencies, public domain. The generator
uses integer percentages, averages the two sex-specific first-name frequencies,
and compares that with the surname frequency over the whole population. Only
nonzero published frequencies are retained. No data comes from Apple's dictionary.
The 22,872 sorted tokens occupy 343,080 bytes of read-only storage, with no pointer
relocations or mutable cache. Lookup folds case/diacritics into a bounded ASCII
key and binary-searches at most 15 rows, with no per-lookup heap allocation.
Parsing remains linear in input length with a fixed dictionary and compound set.
Regenerate by downloading these three text files to a scratch directory and run:

    python3 tests/generate-person-name-roles.py DATA_DIR src/NSPersonNameLatinRoles.inc

This is not an exhaustive linguistic model. The Census is US-biased, very rare
names and non-ASCII names without an ASCII decomposition have no population
prior, and the observed compound-given lexicon is finite. Locales do not yet
select different parsing vocabularies. Ambiguous/all-unknown names still use the
existing positional fallback. Retained observations include differences for
`Unknown Jonathan`, `Jonathan Unknown`, and `Foo Bar Baz Qux`; see lane REMAINING.md.
No claim of arbitrary Apple archive interchange or unsegmented CJK parsing is made.

Verification:

    qv-slot build python3 foundation/tests/person-name-native.py --parsing-contract --source-revision 0237ce8 --expect-failure
    qv-slot build python3 foundation/tests/person-name-native.py --parsing-contract
    qv-slot build python3 foundation/tests/person-name-native.py
    QV_RUN=1 ./run-qvdiff.sh

The native tests execute production Objective-C on Linux libobjc with primitive
Foundation adapters and UBSan; the last command compares actual guest Foundation
with the same Mac-compiled executable. The corrected Anne Marie expectations in
the older native test are explicitly established by both new oracle observations.
