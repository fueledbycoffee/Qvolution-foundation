// Private POSIX implementation shared with the native filesystem regression.
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static int NSFileContentsEqualRegular(const char *left, const char *right)
{
    int a = open(left, O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
    if (a < 0) return 0;
    int b = open(right, O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
    if (b < 0) { close(a); return 0; }
    struct stat sa, sb;
    int equal = fstat(a, &sa) == 0 && fstat(b, &sb) == 0 &&
        S_ISREG(sa.st_mode) && S_ISREG(sb.st_mode) && sa.st_size == sb.st_size;
    unsigned char first[16384], second[16384];
    while (equal)
    {
        ssize_t n;
        do { n = read(a, first, sizeof(first)); } while (n < 0 && errno == EINTR);
        if (n < 0) { equal = 0; break; }
        size_t offset = 0;
        while (offset < (size_t)n)
        {
            ssize_t m;
            do { m = read(b, second + offset, n - offset); } while (m < 0 && errno == EINTR);
            if (m <= 0) { equal = 0; break; }
            offset += m;
        }
        if (!equal || memcmp(first, second, n) != 0) { equal = 0; break; }
        if (n == 0)
        {
            ssize_t m;
            do { m = read(b, second, 1); } while (m < 0 && errno == EINTR);
            equal = m == 0;
            break;
        }
    }
    close(a);
    close(b);
    return equal;
}

static int NSFileContentsEqualPaths(const char *left, const char *right)
{
    if (left == NULL || right == NULL) return 0;
    struct stat a, b;
    if (lstat(left, &a) != 0 || lstat(right, &b) != 0 || (a.st_mode & S_IFMT) != (b.st_mode & S_IFMT)) return 0;
    if (a.st_dev == b.st_dev && a.st_ino == b.st_ino) return 1;
    if (S_ISREG(a.st_mode))
    {
        return a.st_size == b.st_size && NSFileContentsEqualRegular(left, right);
    }
    if (S_ISLNK(a.st_mode))
    {
        if (a.st_size != b.st_size || a.st_size < 0 || (uintmax_t)a.st_size >= SIZE_MAX) return 0;
        size_t size = (size_t)a.st_size + 1;
        char *first = malloc(size), *second = malloc(size);
        int equal = first != NULL && second != NULL &&
            readlink(left, first, size) == a.st_size && readlink(right, second, size) == b.st_size &&
            memcmp(first, second, a.st_size) == 0;
        free(first);
        free(second);
        return equal;
    }
    if (!S_ISDIR(a.st_mode)) return 0;
    DIR *first = opendir(left), *second = opendir(right);
    if (first == NULL || second == NULL)
    {
        if (first != NULL) closedir(first);
        if (second != NULL) closedir(second);
        return 0;
    }
    size_t leftCount = 0, rightCount = 0;
    int equal = 1;
    struct dirent *entry;
    while (equal)
    {
        errno = 0;
        entry = readdir(first);
        if (entry == NULL) { equal = errno == 0; break; }
        if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) continue;
        leftCount++;
        size_t leftLength = strlen(left), rightLength = strlen(right), nameLength = strlen(entry->d_name);
        char *childLeft = malloc(leftLength + nameLength + 2), *childRight = malloc(rightLength + nameLength + 2);
        if (childLeft == NULL || childRight == NULL) equal = 0;
        else
        {
            memcpy(childLeft, left, leftLength);
            childLeft[leftLength] = '/';
            memcpy(childLeft + leftLength + 1, entry->d_name, nameLength + 1);
            memcpy(childRight, right, rightLength);
            childRight[rightLength] = '/';
            memcpy(childRight + rightLength + 1, entry->d_name, nameLength + 1);
            equal = NSFileContentsEqualPaths(childLeft, childRight);
        }
        free(childLeft);
        free(childRight);
    }
    while (equal)
    {
        errno = 0;
        entry = readdir(second);
        if (entry == NULL) { equal = errno == 0; break; }
        if (strcmp(entry->d_name, ".") && strcmp(entry->d_name, "..")) rightCount++;
    }
    closedir(first);
    closedir(second);
    return equal && leftCount == rightCount;
}
