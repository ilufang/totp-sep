//
//  DBEditorViewController.m
//  totp
//
//  Created by Fang Lu on 9/17/23.
//

#import "DBEditorViewController.h"

@interface DBEditorViewController ()
@property (weak, nonatomic) IBOutlet UITextView *editor;

@end

@implementation DBEditorViewController

@synthesize host = _host;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
	_editor.text = _host.db;
	NSLayoutConstraint *kbConstraint = [self.view.keyboardLayoutGuide.topAnchor constraintEqualToSystemSpacingBelowAnchor:_editor.bottomAnchor multiplier:1];
	kbConstraint.active = true;
}

- (NSString *)db {
	return _editor.text;
}

- (void)setDb:(NSString *)db {
	_editor.text = db;
}

- (IBAction)dismissClicked {
	_host.db = _editor.text;
	[self dismissViewControllerAnimated:YES completion:nil];
}

@end
