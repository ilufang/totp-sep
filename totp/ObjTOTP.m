//
//  ObjTOTP.m
//  totp
//
//  Created by Fang Lu on 9/17/23.
//

#import "ObjTOTP.h"

#include "totp.h"

@implementation ObjTOTP

BOOL _urlDirty = NO;
totp_params_t _params = {
	.period = 30,
	.digits = 6,
	.algorithm = "SHA1"
};
NSString *_url;
@synthesize name = _name;
@synthesize key = _key;

+ (nonnull ObjTOTP *)TOTPWithURLString:(nonnull NSString *)urlstr {
	ObjTOTP *ret = [[ObjTOTP alloc] init];
	ret.url = urlstr;
	return ret.url ? ret : nil;
}

- (short)period {
	return _params.period;
}

- (void)setPeriod:(short)period {
	_params.period = period;
	_urlDirty = YES;
}

- (short)digits {
	return _params.digits;
}

- (void)setDigits:(short)digits {
	_params.digits = digits;
	_urlDirty = YES;
}

- (const char *)algorithm {
	return _params.algorithm;
}

- (void)setAlgorithm:(const char *)algorithm {
	_params.algorithm = (char *)algorithm;
	_urlDirty = YES;
}

- (void)setKey:(NSString *)key {
	_key = key;
	_urlDirty = YES;
}

- (void)setName:(NSString *)name {
	_name = name;
	_urlDirty = YES;
}

- (NSString *)url {
	if (_urlDirty) {
		_urlDirty = NO;
		_url = nil;
		// Regenerate URL
		if (!_name || !_key) {
			return nil;
		}
		NSURLComponents *comp = [[NSURLComponents alloc] init];
		comp.scheme = @"otpauth";
		comp.host = @"totp";
		comp.path = [@"/" stringByAppendingString:_name];
		comp.query = [NSString stringWithFormat:@"secret=%@&algorithm=%s&digits=%d&period=%d", _key, _params.algorithm, _params.digits, _params.period];
		_url = comp.string;
	}
	return _url;
}

- (void) setUrl:(NSString *)urlstr {
	_url = nil;
	_urlDirty = NO;
	NSURLComponents *url = [NSURLComponents componentsWithString:urlstr];
	if (!url || !url.scheme || !url.host || !url.path || !url.queryItems ||
		strcasecmp(url.scheme.UTF8String, "otpauth") ||
		strcasecmp(url.host.UTF8String, "totp")) {
		return;
	}
	_name = [url.path substringFromIndex:1];
	_params = TOTP_PARAMS_DEFAULT;
	for (NSURLQueryItem *query in url.queryItems) {
		if (strcasecmp(query.name.UTF8String, "secret") == 0) {
			_key = query.value;
		} else if (strcasecmp(query.name.UTF8String, "digits") == 0) {
			_params.digits = query.value.intValue;
			if (!_params.digits) {
				return;
			}
		} else if (strcasecmp(query.name.UTF8String, "period") == 0) {
			_params.period = query.value.intValue;
			if (!_params.period) {
				return;
			}
		} else if (strcasecmp(query.name.UTF8String, "algorithm") == 0) {
			if (strcasecmp(query.value.UTF8String, "SHA1") == 0) {
				_params.algorithm = "SHA1";
			} else if (strcasecmp(query.value.UTF8String, "SHA256") == 0) {
				_params.algorithm = "SHA256";
			} else if (strcasecmp(query.value.UTF8String, "SHA512") == 0) {
				_params.algorithm = "SHA512";
			} else {
				return;
			}
		}
	}
	// ALL GOOD
	_url = urlstr;
}

- (long)getCode {
	return [self getCodeAtTime:time(NULL)];
}

- (long)getCodeAtTime: (time_t)t {
	return totp_gen(t, _key.UTF8String, &_params);
}


@end
