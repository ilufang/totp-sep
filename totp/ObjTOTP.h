//
//  ObjTOTP.h
//  totp
//
//  Created by Fang Lu on 9/17/23.
//

#import <Foundation/Foundation.h>
#include <time.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjTOTP : NSObject

@property (strong, nonatomic) NSString *key;
@property (strong, nonatomic) NSString *name;
@property (nonatomic) short period;
@property (nonatomic) short digits;
@property (nonatomic) const char *algorithm;

@property (strong, nonatomic) NSString *url;

+ (ObjTOTP *) TOTPWithURLString: (NSString *)urlstr;

- (long) getCode;
- (long) getCodeAtTime: (time_t)t;

@end

NS_ASSUME_NONNULL_END
