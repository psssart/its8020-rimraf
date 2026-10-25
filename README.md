# rimraf

`rimraf` removes the files and directories given on the command line, directories recursively,
like `rm -rf`. It walks directory trees with the POSIX `*at()` functions (`openat`, `fstatat`,
`unlinkat`) relative to open directory file descriptors, never follows symbolic links, and
refuses to remove `.`, `..` and the root directory.

**Warning:** this program permanently deletes data. There is no trash and no undo.

## Platform

Linux only. The program uses POSIX.1-2008 functions (`openat`, `fstatat`, `unlinkat`,
`fdopendir`) and `getopt_long` from glibc.

Tested on Ubuntu 24.04.4 LTS under WSL2 on Windows 11, with
gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0.

## Build

```sh
make         # release build: ./rimraf
make debug   # rebuild with -g -O0 and AddressSanitizer + UBSan
make test    # build and run the test suite
make format  # format the sources with clang-format
make clean
```

`make debug` starts with `make clean`, so that objects built with different flags are never
mixed. Run `make clean` before going back to a normal build.

## Run

```sh
./rimraf [OPTION]... PATH...
```

## Usage

```
$ ./rimraf --help
Usage: ./rimraf [OPTION]... PATH...
Remove each PATH. Directories are removed recursively.

  -i, --interactive  ask once for each PATH before removing it
  -v, --verbose      print every removed entry
  -h, --help         show this help and exit

Symbolic links are never followed. '.', '..' and '/' are refused.
Exit status: 0 on success, 1 if any PATH failed, 2 on usage error.
```

## Examples

`link` is a symbolic link to the directory `notes`. Only the link is removed, `notes` stays.
Entries inside a directory come in the order `readdir` returns them.

```
$ rimraf -v build link/
removed 'build/obj/main.o'
removed 'build/obj'
removed 'build/app'
removed 'build'
removed 'link'

$ rimraf . missing
rimraf: refusing to remove '.' or '..': '.'
rimraf: cannot remove 'missing': No such file or directory
$ echo $?
1

$ rimraf -i notes
rimraf: remove 'notes' recursively? [y/N] n

$ rimraf -- -file-with-dash
```

## Behaviour

- **Symbolic links are never followed.** A symlink, including a dangling one, is removed
  itself. Its target is not touched, even if the target is a directory.
- **Trailing slashes** are stripped first (a lone `/` stays `/`). So `link/`, where `link` is a
  symlink to a directory, removes only the link and never the contents of the target.
- **Refused arguments:** a path whose last component is `.` or `..` (`.`, `./`, `a/..`, `b/.`),
  and the root directory. The root is detected by comparing device and inode numbers with those
  of `/`, so `//` or `///` are caught as well. A refused argument is an error. The other
  arguments are still processed.
- **Errors:** inside one argument's tree, the first error stops the removal of that argument and
  is reported as `rimraf: cannot remove 'full/path': reason` on stderr. Then the next argument is
  processed. There are no permission tricks: if an entry cannot be removed (for example
  `Permission denied`), that is an error.
- **`-i`** asks once per command-line argument, on stderr. Only `y`, `Y` or `yes` confirm.
  Anything else, an empty line or end of input means "no", and the argument is skipped without
  an error.
- **`-v`** prints `removed 'path'` to stdout for every removed entry. A directory comes after its
  contents.
- **Exit codes:** `0` if everything requested was removed (or skipped by answering "no" to
  `-i`). `1` if at least one argument failed or was refused, or if stdout could not be written.
  `2` on a usage error (unknown option, no operand).

## Implementation notes

Every directory is opened with `openat(parent_fd, name, O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)`
and read with `fdopendir`/`readdir`. Its entries are examined with
`fstatat(fd, name, AT_SYMLINK_NOFOLLOW)` and removed with `unlinkat(fd, name, ...)`, so all
work is relative to an already opened directory. No path strings are built for system calls,
and the program never calls `chdir`. If a directory is replaced by a symbolic link between
`fstatat` and `openat`, `O_NOFOLLOW` makes `openat` fail, so the program can never be tricked
into descending into the link target. Full paths for messages are printed from a linked list of
path components kept on the stack (`FullPath`), so the program itself never calls `malloc`.

Source files:

- `main.c`: command line parsing, the `-i` prompt, the loop over arguments and the exit code.
- `check.c`: strips trailing slashes and refuses `.`, `..` and the root directory.
- `remove.c`: the recursive removal.
- `fullpath.c`: prints a `FullPath` chain.

## Limitations

- Each level of nesting keeps one directory file descriptor open. A tree deeper than the open
  file limit (`ulimit -n`, usually 1024) fails with `Too many open files`.
- Linux only, see [Platform](#platform).
- There is no `--one-file-system`: mount points inside a tree are descended into.

## Testing

```sh
make test
```

`tests/run.sh` creates its own sandbox with `mktemp -d` under `/tmp` and builds a fresh tree for
every case. For each case it checks the exit code, stdout, stderr and the resulting files. It
prints `PASS`/`FAIL` per case and a summary, and exits non-zero if anything failed. Permission
cases are skipped when run as root. Refusal of the root directory is deliberately not tested by
running the program on `/`.

The code was also checked with `make debug` (AddressSanitizer + UBSan) and with
`valgrind --leak-check=full --track-fds=yes`: no errors, no leaks, no file descriptors left
open.

## AI usage

I used Claude Code to write tests (as planned), README.md, format code, and for consultation. 
All AI-generated output was thoroughly reviewed. I wrote the core components myself.

## License

MIT, see [LICENSE](LICENSE). Every source file carries an `SPDX-License-Identifier: MIT` line.
