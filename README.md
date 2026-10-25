# rimraf

Recursive file and directory removal tool in C for Linux, using the `*at()` system calls.

## Build

```sh
make         # release build: ./rimraf
make debug   # rebuild with -g -O0 and AddressSanitizer + UBSan
make clean
```
