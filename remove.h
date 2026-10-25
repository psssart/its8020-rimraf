// SPDX-License-Identifier: MIT

#pragma once

#include <stdbool.h>

// Removes path (recursively for directories) and reports any error on stderr.
// Returns true if everything was removed.
bool remove_path(const char *path, bool verbose);
