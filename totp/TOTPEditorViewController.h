//
//  TOTPEditorViewController.h
//  totp
//
//  Created by Fang Lu on 9/18/23.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "ObjTOTP.h"
#import "CodeListViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface TOTPEditorViewController : UIViewController <AVCaptureMetadataOutputObjectsDelegate>

@property (weak, nonatomic) ObjTOTP *totp;
@property (weak, nonatomic) CodeListViewController *host;

@end

NS_ASSUME_NONNULL_END
