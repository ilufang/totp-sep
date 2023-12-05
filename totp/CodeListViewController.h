//
//  CodeListViewController.h
//  totp
//
//  Created by Fang Lu on 9/5/23.
//

#import <UIKit/UIKit.h>

@interface CodeListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) NSString *db;

+ (void)appendOTPURL: (NSString *)url;

- (void)regenerateDB;

@end

