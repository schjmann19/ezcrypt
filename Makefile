# Makefile for ezcrypt - supports native builds
# Usage:
#   make                  # Build for native platform (Linux or macOS)
#   make release          # Release build for native platform
#   make install          # Install the built program
#   make clean            # Clean build artifacts

# --- Target Platform Detection ---
UNAME_S := $(shell uname -s 2>/dev/null || echo MINGW)
ifeq ($(UNAME_S),Linux)
    PLATFORM = linux
else ifeq ($(UNAME_S),Darwin)
    PLATFORM = darwin
else
    PLATFORM = windows
endif

# Allow override: make PLATFORM=windows
ifndef PLATFORM
    PLATFORM = linux
endif

# --- Compiler Selection ---
ifeq ($(PLATFORM),windows)
    CC = x86_64-w64-mingw32-gcc
    TARGET_EXE = ezcrypt.exe
    LDFLAGS_PLATFORM = -static-libgcc
    MINGW_PREFIX = /usr/x86_64-w64-mingw32
    CFLAGS_PLATFORM = -I$(MINGW_PREFIX)/include
    LDFLAGS_PLATFORM += -L$(MINGW_PREFIX)/lib
else
    CC = cc # tested on gcc and clang
    TARGET_EXE = ezcrypt
    LDFLAGS_PLATFORM =
    CFLAGS_PLATFORM = -D_POSIX_C_SOURCE=200809L
endif

# --- Base Compilation Flags ---
CFLAGS_BASE = -std=c99 -O2 -Wall -Wextra -Werror -pedantic \
    -Wshadow -Wconversion -Wsign-conversion -Wformat=2 \
    -Wundef -Wnull-dereference -Wstrict-prototypes \
    -Wmissing-prototypes -Wimplicit-fallthrough

# Sanitizers only work on native Linux builds
ifeq ($(PLATFORM),linux)
    LDFLAGS_BASE = -fsanitize=address,undefined,leak
else
    LDFLAGS_BASE =
endif

CFLAGS = $(CFLAGS_BASE) $(CFLAGS_PLATFORM)
LDFLAGS = $(LDFLAGS_BASE) $(LDFLAGS_PLATFORM)
LIBS = -lsodium

SRC_DIR = src
OBJ_DIR = obj/$(PLATFORM)
BIN_DIR = bin
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
DESTDIR ?=

SRCS = $(SRC_DIR)/main.c $(SRC_DIR)/crypto.c
OBJS = $(OBJ_DIR)/main.o $(OBJ_DIR)/crypto.o

# --- Targets ---
all: $(TARGET_EXE)

# Release build for current platform
release: CFLAGS = $(CFLAGS_BASE) $(CFLAGS_PLATFORM) -O3 -flto -march=native -mtune=native -DNDEBUG
release: LDFLAGS = $(LDFLAGS_BASE) $(LDFLAGS_PLATFORM) -flto -s
release: clean $(TARGET_EXE)

install: $(TARGET_EXE)
	@mkdir -p $(DESTDIR)$(BINDIR)
	install -m 755 $(TARGET_EXE) $(DESTDIR)$(BINDIR)/$(TARGET_EXE)

# Link
$(TARGET_EXE): $(OBJS)
	@mkdir -p $(BIN_DIR)
	$(CC) $(OBJS) -o $@ $(LDFLAGS) $(LIBS)

# Compile
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf obj/ *.exe ezcrypt

.PHONY: all clean release install