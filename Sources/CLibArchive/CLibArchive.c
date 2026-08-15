#include "CLibArchive.h"

/* Clang module trampoline. All archive work is implemented in Swift via libarchive. */
int archivist_clibarchive_present(void) {
    return ARCHIVE_VERSION_NUMBER;
}
