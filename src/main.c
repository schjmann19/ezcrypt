#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sodium.h>
#include <unistd.h>
#include <termios.h>
#include "crypto.h"

#define PASSWORD_MAX 1024
#define BUFSIZE 4096

/* Read password from stdin with echo disabled */
static int read_password(char *buf, size_t bufsize) {
    struct termios oldt, newt;
    if (bufsize == 0 || buf == NULL) {
        return -1;
    }

    if (tcgetattr(STDIN_FILENO, &oldt) != 0) {
        return -1;
    }

    newt = oldt;
    newt.c_lflag &= ~(tcflag_t)ECHO;

    if (tcsetattr(STDIN_FILENO, TCSANOW, &newt) != 0) {
        return -1;
    }

    if (fgets(buf, (int)bufsize, stdin) == NULL) {
        tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
        return -1;
    }

    tcsetattr(STDIN_FILENO, TCSANOW, &oldt);

    size_t len = strlen(buf);
    if (len > 0 && buf[len - 1] == '\n') {
        buf[len - 1] = '\0';
    }
    return 0;
}

/* Copy file to stdout */
static int copy_to_stdout(const char *filepath) {
    FILE *f = fopen(filepath, "rb");
    if (!f) {
        return -1;
    }

    unsigned char buf[BUFSIZE];
    size_t n;
    while ((n = fread(buf, 1, BUFSIZE, f)) > 0) {
        if (fwrite(buf, 1, n, stdout) != n) {
            fclose(f);
            return -1;
        }
    }

    fclose(f);
    return 0;
}

int main(int argc, char **argv) {
    if (sodium_init() < 0)
        return 1;

    if (argc != 3) {
        fprintf(stderr, "Usage: %s -e|-d <file>\n", argv[0]);
        fprintf(stderr, "\nRead password from stdin and process file:\n");
        fprintf(stderr, "  %s -e file.txt > file.enc\n", argv[0]);
        fprintf(stderr, "  %s -d file.enc > file.txt\n", argv[0]);
        return 1;
    }

    const char *mode = argv[1];
    const char *infile = argv[2];
    char password_buf[PASSWORD_MAX] = {0};
    char tempfile[256];

    if (strcmp(mode, "-e") != 0 && strcmp(mode, "-d") != 0) {
        fprintf(stderr, "Mode must be -e (encrypt) or -d (decrypt)\n");
        return 1;
    }

    /* Read password from stdin */
    if (read_password(password_buf, sizeof(password_buf)) != 0) {
        fprintf(stderr, "Failed to read password\n");
        return 1;
    }

    /* Create temp file */
    snprintf(tempfile, sizeof(tempfile), "/tmp/ezcrypt.XXXXXX");
    int fd = mkstemp(tempfile);
    if (fd < 0) {
        fprintf(stderr, "Failed to create temp file\n");
        sodium_memzero(password_buf, sizeof(password_buf));
        return 1;
    }
    close(fd);

    int rc = 1;

    if (strcmp(mode, "-e") == 0) {
        rc = encrypt_file(password_buf, infile, tempfile);
    } else {
        rc = decrypt_file(password_buf, infile, tempfile);
    }

    if (rc == 0) {
        rc = copy_to_stdout(tempfile);
    }

    /* Cleanup */
    unlink(tempfile);
    sodium_memzero(password_buf, sizeof(password_buf));

    return rc;
}

