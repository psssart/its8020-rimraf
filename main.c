// SPDX-License-Identifier: MIT

#include "check.h"

#include <errno.h>
#include <getopt.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { EXIT_USAGE = 2 };

static void usage(FILE *out, const char *argv0) {
    fprintf(out,
            "Usage: %s [OPTION]... PATH...\n"
            "Remove each PATH. Directories are removed recursively.\n"
            "\n"
            "  -i, --interactive  ask once for each PATH before removing it\n"
            "  -v, --verbose      print every removed entry\n"
            "  -h, --help         show this help and exit\n"
            "\n"
            "Symbolic links are never followed. '.', '..' and '/' are refused.\n"
            "Exit status: 0 on success, 1 if any PATH failed, 2 on usage error.\n",
            argv0);
}

static void try_help(const char *argv0) {
    fprintf(stderr, "Try '%s --help' for more information.\n", argv0);
}

// Strips trailing slashes from path in place and reports why it must not be removed.
static bool path_allowed(char *path) {
    strip_trailing_slashes(path);
    switch (check_path(path)) {
    case CHECK_OK:
        return true;
    case CHECK_DOT:
        fprintf(stderr, "rimraf: refusing to remove '.' or '..': '%s'\n", path);
        return false;
    case CHECK_ROOT:
        fprintf(stderr, "rimraf: refusing to remove root directory: '%s'\n", path);
        return false;
    case CHECK_ERROR:
        fprintf(stderr, "rimraf: cannot stat '/': %s\n", strerror(errno));
        return false;
    }
    return false;
}

int main(int argc, char *argv[]) {
    static const struct option long_options[] = {
        {"help", no_argument, NULL, 'h'},
        {"interactive", no_argument, NULL, 'i'},
        {"verbose", no_argument, NULL, 'v'},
        {NULL, 0, NULL, 0},
    };

    bool interactive = false;
    bool verbose = false;
    int opt;
    while ((opt = getopt_long(argc, argv, "hiv", long_options, NULL)) != -1) {
        switch (opt) {
        case 'h':
            usage(stdout, argv[0]);
            // A help text that could not be written is an error too.
            if (fflush(stdout) == EOF) {
                perror("rimraf: write error");
                return EXIT_FAILURE;
            }
            return EXIT_SUCCESS;
        case 'i':
            interactive = true;
            break;
        case 'v':
            verbose = true;
            break;
        default:
            // getopt_long has already printed what was wrong.
            try_help(argv[0]);
            return EXIT_USAGE;
        }
    }

    if (optind >= argc) {
        fprintf(stderr, "rimraf: missing operand\n");
        try_help(argv[0]);
        return EXIT_USAGE;
    }

    // Placeholders.
    (void)interactive;
    (void)verbose;

    int status = EXIT_SUCCESS;
    for (int i = optind; i < argc; i++) {
        if (!path_allowed(argv[i])) {
            status = EXIT_FAILURE;
            continue;
        }
        fprintf(stderr, "rimraf: not implemented yet: '%s'\n", argv[i]);
        status = EXIT_FAILURE;
    }
    return status;
}
