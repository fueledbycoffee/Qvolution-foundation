# This is a Darwin executable; execute in an explicitly selected private runtime.
add_darling_executable(foundation_import_exports load-exports.c)
target_link_libraries(foundation_import_exports system)
