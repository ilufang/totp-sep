//
//  keychip2.m
//  cake
//
//  Created by Fang Lu on 7/7/22.
//

#import <Foundation/Foundation.h>
#include <CommonCrypto/CommonCryptor.h>
#include "keychip2.h"

#define debug_perror(msg, error) NSLog(@"%s: %@", (msg), (__bridge_transfer NSError *)(error))
#define debug_printf(...) NSLog(__VA_ARGS__)

int keychip2_get_key(const char *label, uint8_t *pub) {
    CFErrorRef error = NULL;

    NSData *tag = [NSData dataWithBytes:label length:strlen(label)];
    NSDictionary *getquery = @{ (id)kSecClass: (id)kSecClassKey,
                                (id)kSecAttrApplicationTag: tag,
                                (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
                                (id)kSecReturnRef: @YES,
                             };
    
    SecKeyRef key;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)getquery,
                                          (CFTypeRef *)&key);
    
    if (status == errSecItemNotFound) {
        // Create
        SecAccessControlRef access = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, kSecAccessControlPrivateKeyUsage | kSecAccessControlUserPresence, &error);
        if (error) {
            NSError *err = CFBridgingRelease(error);
			debug_printf(@"Error during access control flags creation: %@\n", err);
            return -ENODEV;
        }

        NSDictionary *attributes = @{
            (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
            (id)kSecAttrKeySizeInBits: @256,
            (id)kSecAttrTokenID: (id)kSecAttrTokenIDSecureEnclave,
            (id)kSecPrivateKeyAttrs: @{
                (id)kSecAttrIsPermanent: @YES,
                (id)kSecAttrApplicationTag: tag,
                (id)kSecAttrAccessControl: (__bridge id)access,
            },
        };

        key = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &error);
        if (!key) {
            NSError *err = CFBridgingRelease(error);  // ARC takes ownership
			debug_printf(@"Keygen failure: %@", err);
            return -ENODEV;
        }
    } else if (status!=errSecSuccess) {
		debug_printf(@"Key retrieval failure: %d", status);
        return -ENODEV;
    }

    SecKeyRef pubkey = SecKeyCopyPublicKey(key);
    CFDataRef keydata = SecKeyCopyExternalRepresentation(pubkey, &error);
    if (error) {
        NSError *err = CFBridgingRelease(error);  // ARC takes ownership
		debug_printf(@"Export failed %@", err);
        return -ENODEV;
    }
    
    const uint8_t *keytext = CFDataGetBytePtr(keydata);
    size_t keylen = CFDataGetLength(keydata);
    memcpy(pub, keytext, keylen);
    return 0;
}
    
int keychip2_sign(const char *label, char *msg, uint8_t *sig) {
    CFErrorRef error = NULL;

	NSData *tag = [NSData dataWithBytes:label length:strlen(label)];
    NSDictionary *getquery = @{ (id)kSecClass: (id)kSecClassKey,
                                (id)kSecAttrApplicationTag: tag,
                                (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
                                (id)kSecReturnRef: @YES,
                             };
    
    SecKeyRef key;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)getquery,
                                          (CFTypeRef *)&key);
    
    if (status == errSecItemNotFound) {
        return -ENOENT;
    } else if (status!=errSecSuccess) {
		debug_printf(@"Key retrieval failure: %d", status);
        return -ENODEV;
    }

    SecKeyAlgorithm algorithm = kSecKeyAlgorithmECDSASignatureMessageX962SHA256;
    BOOL canSign = SecKeyIsAlgorithmSupported(key, kSecKeyOperationTypeSign, algorithm);
    if (canSign == NO) {
		debug_printf(@"Sig algo not supported");
        return -ENODEV;
    }
    
    NSData* data2sign = [NSData dataWithBytes:msg length:strlen(msg)];
    CFDataRef signature;
    signature = SecKeyCreateSignature(key, algorithm, (__bridge CFDataRef)data2sign, &error);
    if (!signature) {
        NSError *err = CFBridgingRelease(error);  // ARC takes ownership
		debug_printf(@"Sign failed %@", err);
        return -ENODEV;
    }
    const uint8_t *sigtext = CFDataGetBytePtr(signature);
    size_t siglen = CFDataGetLength(signature);
    memcpy(sig, sigtext, siglen);
    return 0;
}

static int keychip2_kex2(SecKeyRef key, const uint8_t *pub, uint8_t *secret) {
	CFErrorRef error = NULL;

	NSData *pubkeydata = [NSData dataWithBytes:pub length:65];
	NSDictionary *pubimport = @{
		(id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
		(id)kSecAttrKeyClass: (id)kSecAttrKeyClassPublic,
	};
	SecKeyRef pubkey = SecKeyCreateWithData((__bridge CFDataRef)pubkeydata, (__bridge CFDictionaryRef)pubimport, &error);
	if (error) {
		if (error != (CFErrorRef)-1) {
			debug_perror("open: SecKeyCreateWithData(sealkey)", error);
		}
		CFRelease(key);
		return -ENODEV;
	}

	NSDictionary *kexparams = @{};
	CFDataRef dh = SecKeyCopyKeyExchangeResult(key, kSecKeyAlgorithmECDHKeyExchangeStandard, pubkey, (__bridge CFDictionaryRef)kexparams, &error);
	CFRelease(key);
	CFRelease(pubkey);
	if (error) {
		debug_perror("open: SecKeyCopyKeyExchangeResult(devkey)", error);
		return -ENODEV;
	}
	memcpy(secret, CFDataGetBytePtr(dh), CFDataGetLength(dh));
	CFRelease(dh);

	return 0;
}

int keychip2_kex(const char *label, const uint8_t *pub, uint8_t *secret) {
	CFErrorRef error = NULL;
	
	NSData *tag = [NSData dataWithBytes:label length:strlen(label)];
	NSDictionary *getquery = @{ (id)kSecClass: (id)kSecClassKey,
								(id)kSecAttrApplicationTag: tag,
								(id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
								(id)kSecReturnRef: @YES,
							 };

	SecKeyRef key;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)getquery,
										  (CFTypeRef *)&key);
	
	if (status == errSecItemNotFound) {
		return -ENOENT;
	} else if (status!=errSecSuccess) {
		debug_printf(@"Key retrieval failure: %d", status);
		return -ENODEV;
	}
	
	return keychip2_kex2(key, pub, secret);
}

static int keychip2_symmetric(const uint8_t *keyiv, const void *data_in, void *data_out, size_t len) {
	// Encrypt data with AES
	CCCryptorRef cc;
	size_t nwritten = 0;
	CCCryptorCreateWithMode(kCCEncrypt, kCCModeCTR, kCCAlgorithmAES, ccNoPadding, keyiv+16, keyiv, 16, NULL, 0, 0, 0, &cc);
	CCCryptorUpdate(cc, data_in, len, data_out, len, &nwritten);
	CCCryptorRelease(cc);
	
	return nwritten == len ? 0 : -EINVAL;
}

static int keychip2_mkephemeral(uint8_t *pub, SecKeyRef *priv) {
	CFErrorRef error = NULL;
	
	SecAccessControlRef access = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, kSecAccessControlPrivateKeyUsage, &error);
	if (error) {
		NSError *err = CFBridgingRelease(error);
		debug_printf(@"Error during access control flags creation: %@\n", err);
		return -ENODEV;
	}

	NSDictionary *attributes = @{
		(id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
		(id)kSecAttrKeySizeInBits: @256,
		(id)kSecAttrTokenID: (id)kSecAttrTokenIDSecureEnclave,
		(id)kSecPrivateKeyAttrs: @{
			(id)kSecAttrIsPermanent: @NO,
			(id)kSecAttrAccessControl: (__bridge id)access,
		},
	};

	SecKeyRef key = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &error);
	if (!key) {
		NSError *err = CFBridgingRelease(error);  // ARC takes ownership
		debug_printf(@"Keygen failure: %@", err);
		return -ENODEV;
	}
	*priv = key;
	
	SecKeyRef pubkey = SecKeyCopyPublicKey(key);
	CFDataRef keydata = SecKeyCopyExternalRepresentation(pubkey, &error);
	if (error) {
		NSError *err = CFBridgingRelease(error);  // ARC takes ownership
		debug_printf(@"Export failed %@", err);
		return -ENODEV;
	}
	
	const uint8_t *keytext = CFDataGetBytePtr(keydata);
	size_t keylen = CFDataGetLength(keydata);
	memcpy(pub, keytext, keylen);

	return 0;
}

int keychip2_seal(const uint8_t *pub, const void *data, size_t len, keychip2_ecies_t *meta, void *crypt) {
	int ret;
	uint8_t keyiv[32];
	SecKeyRef epriv;

	ret = keychip2_mkephemeral(&meta->pub_comp, &epriv);
	if (ret) return ret;
	ret = keychip2_kex2(epriv, pub, keyiv);
	if (ret) return ret;
	ret = keychip2_symmetric(keyiv, data, crypt, len);
	if (ret) return ret;
	// ALL GOOD
	return 0;
}

int keychip2_open(const char *label, const void *crypt, size_t len, const keychip2_ecies_t *meta, void *data) {
	int ret;
	uint8_t keyiv[32];
	ret = keychip2_kex(label, &meta->pub_comp, keyiv);
	if (ret) return ret;
	ret = keychip2_symmetric(keyiv, crypt, data, len);
	if (ret) return ret;
	
	// ALL GOOD
	return 0;
}
