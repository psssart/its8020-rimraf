// SPDX-License-Identifier: MIT

#pragma once

#include <stdio.h>

// One path component plus a link to its parent. Lives on the stack of the traversal,
// so a full path can be printed for messages without building strings.
typedef struct s_FullPath {
    const char *name;
    const struct s_FullPath *parent;
} FullPath;

void path_print(FILE *out, const FullPath *path);
