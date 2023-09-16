/**
 * SE-backed key and signature management (no app attestation)
 */

#ifndef keychip2_h
#define keychip2_h

/**
 * Retrieve public key part. The key is automatically generated if it is not yet in the SE.
 *
 * @param label The key name.
 * @param pub Buffer for the public key
 * @return 0 on success. Negative errno otherwise
 */
int keychip2_get_key(const char *label, uint8_t *pub);

/**
 * Create a signature.
 *
 * @param label The key name.
 * @param msg The payload to be signed.
 * @param sig Buffer for the signature
 * @return 0 on success. Negative errno otherwise.
 */
int keychip2_sign(const char *label, char *msg, uint8_t *sig);

/**
 * Derive shared secret with ECDH
 *
 * @param label The key name.
 * @param pub 65-byte public key for the public part of ECDH
 * @param secret Buffer for the derived secret
 * @return 0 on success. Negative errno otherwise.
 */
int keychip2_kex(const char *label, const uint8_t *pub, uint8_t *secret);

/**
 * SEP-ECIES metadata
 */
typedef struct keychip2_ecies {
	uint8_t pub_comp;
	uint8_t pub[64];
//	uint8_t sig[64];
} keychip2_ecies_t;

int keychip2_seal(const uint8_t *pub, const void *data, size_t len, keychip2_ecies_t *meta, void *crypt);

int keychip2_open(const char *label, const void *crypt, size_t len, const keychip2_ecies_t *meta, void *data);

#endif /* keychip_h */
