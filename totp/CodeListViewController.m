//
//  ViewController.m
//  totp
//
//  Created by Fang Lu on 9/5/23.
//

#import "CodeListViewController.h"
#import "DBEditorViewController.h"
#import "TOTPEditorViewController.h"
#import "CodeCell.h"
#import "ObjTOTP.h"

#include <time.h>
#include "keychip2.h"

@interface CodeListViewController ()
@property (weak, nonatomic) IBOutlet UITableView *listview;
@property (weak, nonatomic) IBOutlet UIButton *editorBtn;
@property (weak, nonatomic) IBOutlet UIButton *modifyBtn;

@property (nonatomic) BOOL unlocked;
@property (nonatomic) BOOL unlocking;

@property (nonatomic) time_t last_epoch;
@property (nonatomic) dispatch_source_t timer;
@property (strong, nonatomic) NSMutableArray<ObjTOTP *> *totps;

@property (weak, nonatomic) CodeCell *lastSelection;
@property (nonatomic) int lastSelectionTimer;

@end

@implementation CodeListViewController
static CodeListViewController *_inst;

@synthesize db = _db;
@synthesize unlocked = _unlocked;
@synthesize unlocking = _unlocking;

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
	_totps = [[NSMutableArray alloc] initWithCapacity:lines.count];
	for (NSString *line in lines) {
		NSString *urlstr = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		if (urlstr.length == 0) {
			continue;
		}
		ObjTOTP *totp = [ObjTOTP TOTPWithURLString:urlstr];
		if (totp) {
			[_totps addObject:totp];
		}
	}
	self.unlocked = YES;
	[_listview reloadData];
}

- (void)regenerateDB {
	NSMutableString *db = [[NSMutableString alloc] init];
	for (ObjTOTP *totp in _totps) {
		[db appendString:totp.url];
		[db appendString:@"\n"];
	}
	_db = db;
	[self writeDB:db];
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
		_modifyBtn.enabled = unlocked;
		if (!unlocked) {
			_listview.editing = NO;
			_db = nil;
			_totps = nil;
			[_listview reloadData];
		}
	}
}

- (void)viewDidLoad {
	[super viewDidLoad];

	_inst = self;
	
	// Start periodic updates
	_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
	if (_timer) {
		dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), 200*NSEC_PER_MSEC, 199*NSEC_PER_MSEC);
		dispatch_source_set_event_handler(_timer, ^{
			// interval handler
			if (!self->_unlocked) {
				return;
			}
			
			if (self->_lastSelectionTimer && !--self->_lastSelectionTimer) {
				self->_lastSelection = nil;
			}
			
			// Update codes
			time_t now = time(NULL);
			if (now == self->_last_epoch) {
				return;
			}
			self->_last_epoch = now;
			for (CodeCell *cell in self->_listview.visibleCells) {
				[cell refresh];
			}
		});
		dispatch_activate(_timer);
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillMoveToBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
	
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
	return _totps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (_unlocked) {
		CodeCell *cell = [tableView dequeueReusableCellWithIdentifier:@"totp" forIndexPath:indexPath];
		cell.totp = _totps[indexPath.row];
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

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!_unlocked) {
		return NO;
	}
	
	return indexPath.row < _totps.count;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!_unlocked) {
		return NO;
	}
	
	return indexPath.row < _totps.count;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	switch (editingStyle) {
		case UITableViewCellEditingStyleDelete:
			[_totps removeObjectAtIndex:indexPath.row];
			break;
		default:
			return;
	}
	[self regenerateDB];
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
	long from = sourceIndexPath.row, to = destinationIndexPath.row;
	ObjTOTP *row = _totps[from];
	if (to < from) {
		// Moving upwards
		for (long i = from; i > to; i--) {
			_totps[i] = _totps[i-1];
		}
	} else {
		// Moving downwards
		for (long i = from; i < to; i++) {
			_totps[i] = _totps[i+1];
		}
	}
	_totps[to] = row;
	[self regenerateDB];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!_unlocked) {
		[self lockBtnClick];
		return;
	}
	CodeCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	if (_lastSelection == cell) {
		// Double tap
		_lastSelection = nil;
		[self performSegueWithIdentifier:@"itemEditorSegue" sender:cell.totp];
	} else {
		// Tap
		_lastSelection = cell;
		_lastSelectionTimer = 5;
		[cell onSelect];
	}
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1), dispatch_get_main_queue(), ^{
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
	});
}

- (IBSegueAction DBEditorViewController *)editorSegue:(NSCoder *)coder sender:(id)sender {
	// Open
	DBEditorViewController *dst = [[DBEditorViewController alloc] initWithCoder:coder];
	dst.host = self;
	return dst;
}


- (IBSegueAction TOTPEditorViewController *)itemEditorSegue:(NSCoder *)coder sender:(ObjTOTP *)sender {
	TOTPEditorViewController *dst = [[TOTPEditorViewController alloc] initWithCoder:coder];
	dst.host = self;
	dst.totp = sender;
	return dst;
}

- (IBAction)modifyBtnClick {
	_listview.editing = !_listview.editing;
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
	/*
	if (_unlocking) {
		_unlocking = NO;
		return;
	}
	*/
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
