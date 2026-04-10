#ifndef CRYPTO_H
#define CRYPTO_H

int encrypt_file(const char *password, const char *inpath, const char *outpath);
int decrypt_file(const char *password, const char *inpath, const char *outpath);

#endif