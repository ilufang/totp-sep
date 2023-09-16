//
//  CodeListViewController.h
//  totp
//
//  Created by Fang Lu on 9/5/23.
//

#import <UIKit/UIKit.h>

@interface CodeListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic) NSString *db;

@end

