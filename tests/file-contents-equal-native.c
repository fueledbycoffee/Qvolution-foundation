#define _DEFAULT_SOURCE
#include "../src/NSFileContentsEqual.h"
#include <assert.h>
#include <stdio.h>

static void put(const char *path, const void *bytes, size_t size)
{
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    assert(fd >= 0 && write(fd, bytes, size) == (ssize_t)size && close(fd) == 0);
}
int main(void)
{
    char directory[] = "/tmp/qv-contents-XXXXXX";
    assert(mkdtemp(directory) && chdir(directory) == 0);
    assert(!NSFileContentsEqualPaths(NULL, "a"));
    assert(!NSFileContentsEqualPaths("missing", "missing"));
    put("a", "", 0); put("b", "", 0);
    assert(NSFileContentsEqualPaths("a", "b"));
    unsigned char bytes[65537]; memset(bytes, 'x', sizeof(bytes));
    put("a", bytes, sizeof(bytes)); put("b", bytes, sizeof(bytes));
    assert(NSFileContentsEqualPaths("a", "b"));
    bytes[65536] = 'y'; put("b", bytes, sizeof(bytes));
    assert(!NSFileContentsEqualPaths("a", "b"));
    put("b", bytes, sizeof(bytes) - 1);
    assert(!NSFileContentsEqualPaths("a", "b"));
    assert(link("a", "hard") == 0 && NSFileContentsEqualPaths("a", "hard"));
    assert(symlink("a", "one") == 0 && symlink("a", "two") == 0 && symlink("hard", "three") == 0);
    assert(NSFileContentsEqualPaths("one", "two"));
    assert(!NSFileContentsEqualPaths("one", "three"));
    assert(!NSFileContentsEqualPaths("one", "a"));
    assert(symlink("absent", "dangling1") == 0 && symlink("absent", "dangling2") == 0);
    assert(NSFileContentsEqualPaths("dangling1", "dangling2"));
    assert(mkdir("left", 0700) == 0 && mkdir("right", 0700) == 0);
    assert(NSFileContentsEqualPaths("left", "right"));
    assert(!NSFileContentsEqualPaths("a", "left"));
    assert(mkdir("left/nested", 0700) == 0 && mkdir("right/nested", 0700) == 0);
    put("left/nested/é", bytes, sizeof(bytes)); put("right/nested/é", bytes, sizeof(bytes));
    assert(NSFileContentsEqualPaths("left", "right"));
    assert(symlink("..", "left/nested/loop") == 0 && symlink("..", "right/nested/loop") == 0);
    assert(NSFileContentsEqualPaths("left", "right"));
    put("right/extra", "", 0);
    assert(!NSFileContentsEqualPaths("left", "right"));
    assert(!NSFileContentsEqualPaths("right", "left"));
    // Only remove files and directories created by this test.
    const char *files[] = {"a","b","hard","one","two","three","dangling1","dangling2",
        "left/nested/é","right/nested/é","left/nested/loop","right/nested/loop","right/extra"};
    for (size_t i=0; i<sizeof(files)/sizeof(files[0]); i++) assert(unlink(files[i]) == 0);
    assert(rmdir("left/nested") == 0 && rmdir("right/nested") == 0);
    assert(rmdir("left") == 0 && rmdir("right") == 0);
    assert(chdir("/") == 0 && rmdir(directory) == 0);
    puts("PASS production contents comparison: empty, multiblock, unequal, hardlink, symlink, recursive, Unicode, extra entries");
}
