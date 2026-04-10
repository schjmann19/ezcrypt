# Makefile for ezcrypt - supports Linux and Windows cross-compilation
# Usage:
#   make                  # Build for Linux (default)
#   make windows          # Cross-compile for Windows from Linux
#   make release          # Release build for Linux
#   make windows-release  # Release build for Windows
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
    TARGET_EXE = ezcrpyt.exe
    LDFLAGS_PLATFORM = -static-libgcc
    MINGW_PREFIX = /usr/x86_64-w64-mingw32
    CFLAGS_PLATFORM = -I$(MINGW_PREFIX)/include
    LDFLAGS_PLATFORM += -L$(MINGW_PREFIX)/lib
else
    CC = cc # tested on gcc and clang
    TARGET_EXE = ezcrpyt
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

SRCS = $(SRC_DIR)/main.c $(SRC_DIR)/crypto.c
OBJS = $(OBJ_DIR)/main.o $(OBJ_DIR)/crypto.o

# --- Targets ---
all: $(TARGET_EXE)

# Build for Windows
obj/windows/%.o: $(SRC_DIR)/%.c
	@mkdir -p obj/windows
	x86_64-w64-mingw32-gcc $(CFLAGS_BASE) -I/usr/x86_64-w64-mingw32/include -c $< -o $@

.PHONY: windows
windows: obj/windows/main.o obj/windows/crypto.o
	x86_64-w64-mingw32-gcc obj/windows/main.o obj/windows/crypto.o -o ezcrpyt.exe -L/usr/x86_64-w64-mingw32/lib -static-libgcc -lsodium

.PHONY: windows-release
windows-release: obj/windows/main.o obj/windows/crypto.o
	x86_64-w64-mingw32-gcc obj/windows/main.o obj/windows/crypto.o -o ezcrpyt.exe -L/usr/x86_64-w64-mingw32/lib -static-libgcc -s -lsodium

# Release build for current platform
release: CFLAGS = $(CFLAGS_BASE) $(CFLAGS_PLATFORM) -O3 -flto -march=native -mtune=native -DNDEBUG
release: LDFLAGS = $(LDFLAGS_BASE) $(LDFLAGS_PLATFORM) -flto -s
release: clean $(TARGET_EXE)

# Link
$(TARGET_EXE): $(OBJS)
	@mkdir -p $(BIN_DIR)
	$(CC) $(OBJS) -o $@ $(LDFLAGS) $(LIBS)

# Compile
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf obj/ *.exe ezcrpyt

.PHONY: all clean release windows windows-release