# EZCRYPT

A tiny (>90 semicolons of C!) CLI tool for password authenticated encryption/decryption of files using libsodium; written in pure C. (C99 + POSIX.1-2008)

## Features

- Encrypt files with a password (`enc`).
- Decrypt files with the same password (`dec`).
- Derives a strong key from the password with `crypto_pwhash()` and a random salt.
- Uses `crypto_aead_xchacha20poly1305_ietf()` for authenticated encryption.
- Password always read from stdin (echo disabled for security).
- Output piped to stdout for use with shell redirection and pipes.

## Prerequisites

- C compiler
- `libsodium` installed/present in linker search path

## Build

```bash
make
```
## Usage

Password is read from stdin and output goes to stdout, making it easy to use with pipes:

```bash
# Encrypt
ezcrypt -e file.txt > file.enc

# Decrypt
ezcrypt -d file.enc > file.txt
```

### Details

- Passwords are converted to keys via `crypto_pwhash` (interactive limits).
- Nonce and salt are stored in output (unencrypted header).
- Tampered ciphertext or wrong password fails decryption.
