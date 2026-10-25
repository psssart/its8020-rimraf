// SPDX-License-Identifier: MIT

#include "fullpath.h"

void path_print(FILE *out, const FullPath *path) {
    if (path->parent != NULL) {
        path_print(out, path->parent);
        fputc('/', out);
    }
    fputs(path->name, out);
}
