//
//  CodeCell.h
//  totp
//
//  Created by Fang Lu on 9/16/23.
//

#import <UIKit/UIKit.h>
#import "ObjTOTP.h"

NS_ASSUME_NONNULL_BEGIN

@interface CodeCell : UITableViewCell

@property (nonatomic) int timer;
@property (nonatomic) NSString *code;
@property (nonatomic) NSString *label;
@property (nonatomic) short period;
@property (nonatomic) short digits;
@property (nonatomic) ObjTOTP *totp;

- (void)refresh;

@end

NS_ASSUME_NONNULL_END
