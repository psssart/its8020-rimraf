// SPDX-License-Identifier: MIT

#include "remove.h"

#include "fullpath.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static void report_error(const FullPath *path, int err) {
    fputs("rimraf: cannot remove '", stderr);
    path_print(stderr, path);
    fprintf(stderr, "': %s\n", strerror(err));
}

static void report_removed(const FullPath *path) {
    fputs("removed '", stdout);
    path_print(stdout, path);
    fputs("'\n", stdout);
}

bool remove_path(const char *path, bool verbose) {
    const FullPath fullpath = {path, NULL};

    struct stat st;
    if (fstatat(AT_FDCWD, path, &st, AT_SYMLINK_NOFOLLOW) == -1) {
        report_error(&fullpath, errno);
        return false;
    }

    // If path was swapped since fstatat, unlinkat fails with EISDIR or ENOTDIR.
    int flags = S_ISDIR(st.st_mode) ? AT_REMOVEDIR : 0;
    if (unlinkat(AT_FDCWD, path, flags) == -1) {
        report_error(&fullpath, errno);
        return false;
    }
    if (verbose) {
        report_removed(&fullpath);
    }
    return true;
}
