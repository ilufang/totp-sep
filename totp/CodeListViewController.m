//
//  ViewController.m
//  totp
//
//  Created by Fang Lu on 9/5/23.
//

#import "CodeListViewController.h"
#import "DBEditorViewController.h"
#import "CodeCell.h"
#import "ObjTOTP.h"

#include <time.h>
#include "keychip2.h"

@interface CodeListViewController ()
@property (weak, nonatomic) IBOutlet UITableView *listview;
@property (weak, nonatomic) IBOutlet UIButton *editorBtn;

@property (nonatomic) BOOL unlocked;
@property (nonatomic) BOOL unlocking;

@end

@implementation CodeListViewController
static CodeListViewController *_inst;

@synthesize db = _db;
@synthesize unlocked = _unlocked;
@synthesize unlocking = _unlocking;

NSMutableArray<ObjTOTP *> *totps = nil;
time_t _last_epoch = 0;
dispatch_source_t timer;

- (NSString *)readDB {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *dbPath = [documentsDirectory stringByAppendingPathComponent:@"keys.bin"];
	NSString *metaPath = [documentsDirectory stringByAppendingPathComponent:@"keys.meta"];
	NSData *db_crypt = [NSData dataWithContentsOfFile:dbPath];
	NSData *db_meta = [NSData dataWithContentsOfFile:metaPath];
	int ret;
	if (db_crypt && db_meta) {
		char *data = malloc(db_crypt.length);
		_unlocking = YES;
		ret = keychip2_open("instkey", db_crypt.bytes, db_crypt.length, (const keychip2_ecies_t *)db_meta.bytes, data);

		if (ret != 0) {
			free(data);
			return nil;
		} else {
			return [[NSString alloc] initWithBytesNoCopy:data length:db_crypt.length encoding:NSUTF8StringEncoding freeWhenDone:YES];
		}
	} else {
		// Create empty DB
		return @"";
	}
}

- (void)writeDB: (NSString *)db {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *dbPath = [documentsDirectory stringByAppendingPathComponent:@"keys.bin"];
	NSString *metaPath = [documentsDirectory stringByAppendingPathComponent:@"keys.meta"];
	
	uint8_t pub[65];
	keychip2_ecies_t meta;
	NSData *db_data = [db dataUsingEncoding:NSUTF8StringEncoding];
	NSMutableData *db_crypt = [NSMutableData dataWithLength:db_data.length];
	int ret;
	ret = keychip2_get_key("instkey", pub);
	if (ret != 0) {
		perror("keychip2_get_key");
		return;
	}
	ret = keychip2_seal(pub, db_data.bytes, db_data.length, &meta, db_crypt.mutableBytes);
	if (ret != 0) {
		perror("keychip2_seal");
		return;
	}
	NSData *db_meta = [NSData dataWithBytesNoCopy:&meta length:sizeof(meta) freeWhenDone:NO];
	[db_meta writeToFile:metaPath atomically:NO];
	[db_crypt writeToFile:dbPath atomically:NO];

}

- (void)loadDB: (NSString *)db {
	if (!db) {
		self.unlocked = NO;
		return;
	}
	NSArray<NSString*> *lines = [db componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
	totps = [[NSMutableArray alloc] initWithCapacity:lines.count];
	for (NSString *line in lines) {
		NSString *urlstr = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		if (urlstr.length == 0) {
			continue;
		}
		ObjTOTP *totp = [ObjTOTP TOTPWithURLString:urlstr];
		if (totp) {
			[totps addObject:totp];
		}
	}
	self.unlocked = YES;
	[_listview reloadData];
}

- (void)setDb: (NSString *)db {
	_db = db;
	if (db) {
		[self loadDB:db];
		[self writeDB:db];
	}
}

- (void)setUnlocked:(BOOL)unlocked {
	if (unlocked != _unlocked) {
		_unlocked = unlocked;
		_editorBtn.enabled = unlocked;
		if (!unlocked) {
			_db = nil;
			[_listview reloadData];
		}
	}
}

- (void)viewDidLoad {
	[super viewDidLoad];

	_inst = self;
	
	// Start periodic updates
	timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
	if (timer) {
		dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), 200*NSEC_PER_MSEC, 199*NSEC_PER_MSEC);
		dispatch_source_set_event_handler(timer, ^{
			if (!self->_unlocked) {
				return;
			}
						
			// interval handler
			time_t now = time(NULL);
			if (now == _last_epoch) {
				return;
			}
			_last_epoch = now;
			for (CodeCell *cell in self->_listview.visibleCells) {
				[cell refresh];
			}
		});
		dispatch_activate(timer);
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillMoveToBackground:) name:UIApplicationWillResignActiveNotification object:nil];
	
	// Unlock DB on start
	_unlocked = NO;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1), dispatch_get_main_queue(), ^{
		[self lockBtnClick];
	});
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section > 0) {
		return 0;
	}
	if (!_unlocked) {
		return 1;
	}
	return totps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (_unlocked) {
		CodeCell *cell = [tableView dequeueReusableCellWithIdentifier:@"totp" forIndexPath:indexPath];
		cell.totp = totps[indexPath.row];
		return cell;
	} else {
		return [tableView dequeueReusableCellWithIdentifier:@"locked" forIndexPath:indexPath];
	}
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (_unlocked) {
		[(CodeCell *)cell refresh];
	}
}

- (IBSegueAction DBEditorViewController *)editorSegue:(NSCoder *)coder sender:(id)sender {
	// Open
	DBEditorViewController *dst = [[DBEditorViewController alloc] initWithCoder:coder];
	dst.host = self;
	return dst;
}

- (IBAction)lockBtnClick {
	if (_unlocked) {
		self.unlocked = NO;
	} else {
		// Load DB (manually, do not trigger write)
		_db = [self readDB];
		[self loadDB:_db];
	}
}

- (void)appWillMoveToBackground:(NSNotification *) notification {
	if (_unlocking) {
		_unlocking = NO;
		return;
	}
	self.unlocked = NO;
}

+ (void)appendOTPURL:(NSString *)url {
	if (!_inst.unlocked) {
		[_inst lockBtnClick];
	}
	NSString *db = _inst.db;
	if (!db) {
		return;
	}
	if (![db hasSuffix:@"\n"]) {
		db = [db stringByAppendingString:@"\n"];
	}
	db = [db stringByAppendingString:url];
	_inst.db = db;
}

@end
