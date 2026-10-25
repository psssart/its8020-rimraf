# SPDX-License-Identifier: MIT

CC = gcc
CPPFLAGS = -D_POSIX_C_SOURCE=200809L
WARNINGS = -Wall -Wextra -Wpedantic
CFLAGS = -std=c17 $(WARNINGS) -O2
SANITIZE = -fsanitize=address,undefined -fno-omit-frame-pointer

OBJS = main.o check.o

.PHONY: all debug format clean

all: rimraf

rimraf: $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

debug: clean
	$(MAKE) CFLAGS="-std=c17 $(WARNINGS) -g -O0 $(SANITIZE)" LDFLAGS="$(SANITIZE)"

format:
	clang-format -i $(wildcard *.c *.h)

clean:
	rm -f rimraf $(OBJS)

main.o check.o: check.h
