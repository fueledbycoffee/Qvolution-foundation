// GUESS: the extension-host handshake is unavailable. Fail the process entry explicitly.
#include <stdio.h>
#include <stdlib.h>
int NSExtensionMain(int argc, const char *argv[])
{
    fputs("NSExtensionMain: extension host lifecycle is unavailable\n", stderr);
    return EXIT_FAILURE;
}
