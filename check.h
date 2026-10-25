// SPDX-License-Identifier: MIT

#pragma once

enum check_result {
    CHECK_OK,
    CHECK_DOT,   // last component is "." or ".."
    CHECK_ROOT,  // the root directory itself
    CHECK_ERROR, // could not stat "/", errno is set
};

void strip_trailing_slashes(char *path);
enum check_result check_path(const char *path);
