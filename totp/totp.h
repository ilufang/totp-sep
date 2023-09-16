//
//  totp.h
//  totp
//
//  Created by Fang Lu on 9/9/23.
//

#ifndef totp_h
#define totp_h

#include <stdint.h>
#include <time.h>

typedef struct totp_params {
	short period;
	short digits;
	char *algorithm;
} totp_params_t;

extern const totp_params_t TOTP_PARAMS_DEFAULT;

long totp_gen(time_t t, const char *keystr, const totp_params_t *options);

#endif /* totp_h */
