//
//  DBEditorViewController.h
//  totp
//
//  Created by Fang Lu on 9/17/23.
//

#import <UIKit/UIKit.h>
#import "CodeListViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface DBEditorViewController : UIViewController

@property (nonatomic) NSString *db;
@property (nonatomic) CodeListViewController *host;

@end

NS_ASSUME_NONNULL_END
