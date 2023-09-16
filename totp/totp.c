//
//  totp.c
//  totp
//
//  Created by Fang Lu on 9/9/23.
//

#include "totp.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <CommonCrypto/CommonHMAC.h>

const totp_params_t TOTP_PARAMS_DEFAULT = {
	.period = 30,
	.digits = 6,
	.algorithm = "SHA1"
};

//static const char BASE32[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
static int base32_decode(const char *base32, uint8_t *ret) {
	uint8_t *wptr = ret;
	uint16_t bitbuf = 0;
	int buflen = 0;
	for(int i = 0; i < base32[i]; i++) {
		char c = base32[i];
		if (c >= 'a' && c <= 'z') {
			c -= 'a';
		} else if (c >= 'A' && c <= 'Z') {
			c -= 'A';
		} else if (c >= '2' && c <= '7') {
			c = c - '2' + 26;
		} else {
			return -1;
		}
		bitbuf = (bitbuf << 5) | c;
		for (buflen += 5; buflen >= 8; buflen -= 8) {
			*(wptr++) = (uint8_t)(bitbuf >> (buflen-8));
		}
	}
	if (buflen != 0) {
		bitbuf &= ((~0) << buflen);
		if (bitbuf)
			return -1;
	}
	return (int)(wptr-ret);
}

long totp_gen(time_t t, const char *keystr, const totp_params_t *options) {
	if (!options) {
		options = &TOTP_PARAMS_DEFAULT;
	}
	
	uint8_t key[strlen(keystr) * 5 / 8 + 1];
	int keylen = base32_decode(keystr, key);
	if (keylen < 0) {
		return -1;
	}

	time_t epoch = t / options->period;
	uint8_t timedata[8];
	memset(timedata, 0, 8);
	for (int i = 0; i < sizeof(time_t); i++) {
		timedata[7-i] = epoch & 0xff;
		epoch >>= 8;
	}

	CCHmacAlgorithm alg;
	int maclen;
	if (strcasecmp(options->algorithm, "SHA1") == 0) {
		alg = kCCHmacAlgSHA1;
		maclen = 20;
	} else if (strcasecmp(options->algorithm, "SHA224") == 0) {
		alg = kCCHmacAlgSHA224;
		maclen = 24;
	} else if (strcasecmp(options->algorithm, "SHA256") == 0) {
		alg = kCCHmacAlgSHA256;
		maclen = 32;
	} else if (strcasecmp(options->algorithm, "SHA384") == 0) {
		alg = kCCHmacAlgSHA384;
		maclen = 48;
	} else if (strcasecmp(options->algorithm, "SHA512") == 0) {
		alg = kCCHmacAlgSHA512;
		maclen = 64;
	} else {
		return -1;
	}
	
	uint8_t mac[maclen];
	CCHmac(alg, key, keylen, timedata, 8, mac);
	
	int offset = mac[maclen-1] & 0xf;
	uint32_t otp = 0;
	otp = (otp << 8) | mac[offset+0];
	otp = (otp << 8) | mac[offset+1];
	otp = (otp << 8) | mac[offset+2];
	otp = (otp << 8) | mac[offset+3];
	otp &= 0x7fffffff;
	
	int modulus = 1;
	for (int i = options->digits; i-->0; modulus*=10);
	return otp % modulus;
}

#if SINGLETEST
int main(int argc, char *argv[]) {
	printf("%06ld\n", totp_gen(argv[1], NULL));
	return 0;
}
#endif
