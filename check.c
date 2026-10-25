// SPDX-License-Identifier: MIT

#include "check.h"

#include <fcntl.h>
#include <stdbool.h>
#include <string.h>
#include <sys/stat.h>

void strip_trailing_slashes(char *path) {
    size_t len = strlen(path);
    // A lone "/" must stay "/", so never strip the first character.
    while (len > 1 && path[len - 1] == '/') {
        path[--len] = '\0';
    }
}

static bool is_dot_or_dotdot(const char *name) {
    return strcmp(name, ".") == 0 || strcmp(name, "..") == 0;
}

enum check_result check_path(const char *path) {
    const char *slash = strrchr(path, '/');
    const char *last = slash != NULL ? slash + 1 : path;
    if (is_dot_or_dotdot(last)) {
        return CHECK_DOT;
    }

    struct stat root;
    if (fstatat(AT_FDCWD, "/", &root, 0) == -1) {
        return CHECK_ERROR;
    }
    // A path that cannot be stat'ed is not the root; removing it will report the error.
    // Symlinks are not followed: a link to "/" is just a link and may be removed.
    struct stat st;
    if (fstatat(AT_FDCWD, path, &st, AT_SYMLINK_NOFOLLOW) == 0 && st.st_dev == root.st_dev &&
        st.st_ino == root.st_ino) {
        return CHECK_ROOT;
    }
    return CHECK_OK;
}
