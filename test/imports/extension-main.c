// The unavailable extension-host entry must return failure.
extern int NSExtensionMain(int argc, const char *argv[]);
int main(int argc, char *argv[]) { return NSExtensionMain(argc, (const char **)argv); }
