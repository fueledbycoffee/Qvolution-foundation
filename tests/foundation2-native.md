# Foundation differential regression controls

Run `python3 tests/run-foundation2-native.py --core-source ../corefoundation --out ../native/after` under `dashboard/qv-slot build` from the Foundation clone. All nine sections must pass.

Use `--foundation-revision a2400ec --core-revision f51d51d --out ../native/before --expect-fail` for the pre-change baseline: all nine sections fail on behavioral assertions. The GMT abbreviation addition also fails against `--core-revision d69b2ea --sections zone --out ../native/before-gmt --expect-fail`.

The fixture compiles unchanged production method regions against storage and CF boundary controls. The path builder and ASCII fallback are also production regions. This tests state changes, identity, removal, coercion and dispatch. It does not run the full Foundation/CoreFoundation runtime, execute weak-reference lifetime integration, or establish guest MATCH results.

The lane's `prepare-build.py` snapshots unchanged base objects and generates a small Ninja graph from Stage41g's compiler/link commands. It compiles changed fat objects and links complete i386 and x86_64 Foundation/CoreFoundation payloads. Native `ninja -C ../build -j6` is run inside `qv-slot build`; `ninja -C ../build -n` must report no work. The lane's `run-qvdiff.sh` prepares a private hardlink-copy runtime with copy-on-replacement payloads. It defaults to a full preflight dry run; `QV_RUN=1` enables the supplied eight-check Mac/Darling batch.

Timezone name/equality, dated lookup and the fixed GMT zone's UTC spelling are covered. The oracle's twelve regional UTC±offset abbreviation strings remain unresolved locale presentation. The lane's `ORACLE-QUESTIONS.md` has an authored public API probe; no localized strings are inferred from implementation internals or hardcoded for those regions.
