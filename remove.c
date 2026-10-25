// SPDX-License-Identifier: MIT

#include "remove.h"

#include "fullpath.h"

#include <dirent.h>
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

static bool remove_at(int dirfd, const char *name, const FullPath *path, bool verbose);

// Removes everything inside the directory open as fd. Always closes fd.
static bool clear_dir(int fd, const FullPath *dirpath, bool verbose) {
    DIR *dir = fdopendir(fd);
    if (dir == NULL) {
        int err = errno;
        close(fd);
        report_error(dirpath, err);
        return false;
    }
    // From here on dir owns fd: closedir() closes it, so it must not be closed again.

    bool ok = true;
    for (;;) {
        errno = 0;
        struct dirent *ent = readdir(dir);
        if (ent == NULL) {
            // NULL with errno still 0 is the end of the directory.
            if (errno != 0) {
                report_error(dirpath, errno);
                ok = false;
            }
            break;
        }
        if (strcmp(ent->d_name, ".") == 0 || strcmp(ent->d_name, "..") == 0) {
            continue;
        }
        const FullPath child = {ent->d_name, dirpath};
        if (!remove_at(fd, ent->d_name, &child, verbose)) {
            ok = false;
            break;
        }
    }

    if (closedir(dir) == -1 && ok) {
        report_error(dirpath, errno);
        ok = false;
    }
    return ok;
}

// Removes name relative to dirfd; path is the same entry, for messages.
static bool remove_at(int dirfd, const char *name, const FullPath *path, bool verbose) {
    // d_type from readdir can be DT_UNKNOWN, so always ask the file system.
    struct stat st;
    if (fstatat(dirfd, name, &st, AT_SYMLINK_NOFOLLOW) == -1) {
        report_error(path, errno);
        return false;
    }

    int flags = 0;
    if (S_ISDIR(st.st_mode)) {
        // If name was replaced by a symlink after fstatat, O_NOFOLLOW makes openat fail
        // with ELOOP instead of descending into the link target.
        int fd = openat(dirfd, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (fd == -1) {
            report_error(path, errno);
            return false;
        }
        if (!clear_dir(fd, path, verbose)) {
            return false;
        }
        flags = AT_REMOVEDIR;
    }

    // If name was swapped since fstatat, unlinkat refuses the wrong type (EISDIR, ENOTDIR)
    // and a non-empty directory (ENOTEMPTY), so nothing that was not cleared gets removed.
    if (unlinkat(dirfd, name, flags) == -1) {
        report_error(path, errno);
        return false;
    }
    if (verbose) {
        report_removed(path);
    }
    return true;
}

bool remove_path(const char *path, bool verbose) {
    const FullPath fullpath = {path, NULL};
    return remove_at(AT_FDCWD, path, &fullpath, verbose);
}
