#!/usr/bin/env python3
"""Compile the production cleanup with injected CF ownership/result pairs.

Native-only: no CF, Objective-C runtime, guest, or port-destruction race is run.
The adopted/NULL result is permitted by Apple's published CFMachPort.c final
validity check. Count releases without actually freeing twice (the reviewer's
reproducer), including when CF defers its context release until after return.

Run: python3 tests/machport-context-ownership.py [--revision 5b5770a]
"""
import argparse
import os
from pathlib import Path
import shlex
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--revision', help='test an immutable Git revision')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    if args.revision:
        source = subprocess.check_output(
            ['git', '-C', str(repo), 'show', args.revision + ':src/NSPort.m'],
            text=True)
    else:
        source = (repo / 'src/NSPort.m').read_text()
    start = source.index('Boolean shouldFreeInfo = false;')
    start = source.index('        );', start) + len('        );')
    end = source.index('        CFMachPortSetInvalidationCallBack(', start)
    cleanup = source[start:end]
    assert 'free(context.info)' in cleanup, 'production cleanup not found'
    code = r'''
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#define nil NULL
static unsigned releases;
static void counted_free(void *info) { if (info) ++releases; }
static void *finish_initialization(bool shouldFreeInfo, void *self, void *info) {
    struct { void *info; } context = { info };
#define free counted_free
''' + cleanup + r'''
#undef free
    return self;
}
static int check(const char *name, bool should_free, bool has_port,
                 bool adopted, bool release_before_return) {
    void *info = malloc(1);
    if (!info) abort();
    int port;
    releases = 0;
    if (adopted && release_before_return) counted_free(info);
    void *result = finish_initialization(should_free, has_port ? &port : NULL, info);
    unsigned expected_now = should_free + (adopted && release_before_return);
    bool ok = releases == expected_now && result == (has_port ? &port : NULL);
    if (adopted && !release_before_return) counted_free(info);
    ok = ok && releases == 1;
    printf("%s: releases=%u expected=1; %s\n", name, releases, ok ? "PASS" : "FAIL");
    free(info);
    return !ok;
}
int main(void) {
    int failures = 0;
    failures += check("NULL, adopted, released before return", false, false, true, true);
    failures += check("NULL, adopted, released after return", false, false, true, false);
    failures += check("NULL, not adopted", true, false, false, false);
    failures += check("new port, adopted", false, true, true, false);
    failures += check("existing port, not adopted", true, true, false, false);
    return failures ? EXIT_FAILURE : EXIT_SUCCESS;
}
'''
    with tempfile.TemporaryDirectory(prefix='machport-context-') as temp:
        test_source = Path(temp) / 'ownership.c'
        test_binary = Path(temp) / 'ownership'
        test_source.write_text(code)
        subprocess.run(shlex.split(os.environ.get('CC', 'cc')) +
                       ['-std=c11', '-Wall', '-Wextra', '-Werror',
                        str(test_source), '-o', str(test_binary)], check=True)
        return subprocess.run([str(test_binary)]).returncode


if __name__ == '__main__':
    raise SystemExit(main())
