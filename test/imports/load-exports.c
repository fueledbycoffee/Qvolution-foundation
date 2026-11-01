// Load only the explicitly supplied source-build libraries and their manifests.
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    if (argc < 3 || argc % 2 != 1) return 2;
    size_t count = 0;
    int failed = 0;
    for (int i = 1; i < argc; i += 2) {
        void *library = dlopen(argv[i], RTLD_NOW | RTLD_LOCAL);
        if (!library) { fprintf(stderr, "dlopen %s: %s\n", argv[i], dlerror()); return 1; }
        if (dlsym(library, "__imp_foundation_deliberately_absent")) return 1;
        FILE *manifest = fopen(argv[i + 1], "r");
        if (!manifest) { perror(argv[i + 1]); return 2; }
        char name[8192];
        size_t library_count = 0;
        while (fgets(name, sizeof(name), manifest)) {
            name[strcspn(name, "\r\n")] = 0;
            if (name[0] != '_' || !name[1]) return 2;
            dlerror();
            void *symbol = dlsym(library, name + 1); // Mach-O nm prefix
            const char *error = dlerror();
            if (error || !symbol) {
                fprintf(stderr, "missing %s in %s: %s\n", name, argv[i], error ? error : "null");
                failed = 1;
            }
            ++count;
            ++library_count;
        }
        if (ferror(manifest) || !library_count) return 2;
        fclose(manifest);
        dlclose(library);
    }
    printf("exports checked=%zu failures=%d\n", count, failed);
    return failed;
}
