#include <sodium.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "crypto.h"

#define SALT_LEN  crypto_pwhash_SALTBYTES
#define KEY_LEN   crypto_aead_xchacha20poly1305_ietf_KEYBYTES
#define NONCE_LEN crypto_aead_xchacha20poly1305_ietf_NPUBBYTES

static int derive_key(
    unsigned char *key,
    const char *password,
    unsigned char *salt)
{
    return crypto_pwhash(
        key, KEY_LEN,
        password, strlen(password),
        salt,
        crypto_pwhash_OPSLIMIT_INTERACTIVE,
        crypto_pwhash_MEMLIMIT_INTERACTIVE,
        crypto_pwhash_ALG_DEFAULT
    );
}

int encrypt_file(
    const char *password,
    const char *inpath,
    const char *outpath)
{
    FILE *in = fopen(inpath, "rb");
    if (!in) {
        return -1;
    }

    FILE *out = fopen(outpath, "wb");
    if (!out) {
        fclose(in); return -2;
    }

    unsigned char salt[SALT_LEN];
    randombytes_buf(salt, SALT_LEN);
    fwrite(salt, 1, SALT_LEN, out);

    unsigned char key[KEY_LEN];
    if (derive_key(key, password, salt) != 0) {
        return -3;
    }

    unsigned char nonce[NONCE_LEN];
    randombytes_buf(nonce, NONCE_LEN);
    fwrite(nonce, 1, NONCE_LEN, out);

    fseek(in, 0, SEEK_END);
    long len = ftell(in);
    fseek(in, 0, SEEK_SET);

    unsigned char *plaintext = malloc((size_t)len);
    if (fread(plaintext, 1, (size_t)len, in) != (size_t)len) {
        return -4;
    }

    unsigned char *ciphertext = malloc(
        (size_t)len + crypto_aead_xchacha20poly1305_ietf_ABYTES
    );

    unsigned long long clen;
    crypto_aead_xchacha20poly1305_ietf_encrypt(
        ciphertext, &clen,
        plaintext, (unsigned long long)len,
        NULL, 0,
        NULL,
        nonce,
        key
    );

    fwrite(ciphertext, 1, clen, out);

    sodium_memzero(key, KEY_LEN);
    free(plaintext);
    free(ciphertext);
    fclose(in);
    fclose(out);

    return 0;
}

int decrypt_file(
    const char *password,
    const char *inpath,
    const char *outpath)
{
    FILE *in = fopen(inpath, "rb");
    if (!in) {
        return -1;
    }

    unsigned char salt[SALT_LEN];
    if (fread(salt, 1, SALT_LEN, in) != SALT_LEN) {
        return -1;
    }

    unsigned char key[KEY_LEN];
    if (derive_key(key, password, salt) != 0) {
        return -2;
    }
    unsigned char nonce[NONCE_LEN];
    if (fread(nonce, 1, NONCE_LEN, in) != NONCE_LEN) {
        return -2;
    }

    fseek(in, 0, SEEK_END);
    long clen = ftell(in) - (long)SALT_LEN - (long)NONCE_LEN;
    fseek(in, (long)SALT_LEN + (long)NONCE_LEN, SEEK_SET);

    unsigned char *ciphertext = malloc((size_t)clen);
    if (fread(ciphertext, 1, (size_t)clen, in) != (size_t)clen) {
        return -3;
    }

    unsigned char *plaintext =
        malloc((size_t)clen - crypto_aead_xchacha20poly1305_ietf_ABYTES);

    unsigned long long plen;
    int rc = crypto_aead_xchacha20poly1305_ietf_decrypt(
        plaintext, &plen,
        NULL,
        ciphertext, (unsigned long long)clen,
        NULL, 0,
        nonce,
        key
    );

    if (rc != 0) {
        fprintf(stderr, "Decryption failed (wrong password or tampered data)\n");
        return -3;
    }

    FILE *out = fopen(outpath, "wb");
    fwrite(plaintext, 1, plen, out);

    sodium_memzero(key, KEY_LEN);
    free(ciphertext);
    free(plaintext);
    fclose(in);
    fclose(out);

    return 0;
}

