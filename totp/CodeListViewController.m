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

@end

@implementation CodeListViewController
@synthesize db = _db;

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
	NSString *db = @"";
	int ret;
	if (db_crypt && db_meta) {
		char *data = malloc(db_crypt.length);
		ret = keychip2_open("instkey", db_crypt.bytes, db_crypt.length, (const keychip2_ecies_t *)db_meta.bytes, data);
		if (ret != 0) {
			free(data);
		}
		db = [[NSString alloc] initWithBytesNoCopy:data length:db_crypt.length encoding:NSUTF8StringEncoding freeWhenDone:YES];
	}
	return db;
}

- (void)writeDB: (NSString *)db {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *dbPath = [documentsDirectory stringByAppendingPathComponent:@"keys.bin"];
	NSString *metaPath = [documentsDirectory stringByAppendingPathComponent:@"keys.meta"];
	
	uint8_t pub[65];
	keychip2_ecies_t meta;
	NSMutableData *db_crypt = [NSMutableData dataWithLength:db.length];
	int ret;
	ret = keychip2_get_key("instkey", pub);
	if (ret != 0) {
		perror("keychip2_get_key");
		return;
	}
	ret = keychip2_seal(pub, db.UTF8String, db.length, &meta, db_crypt.mutableBytes);
	if (ret != 0) {
		perror("keychip2_seal");
		return;
	}
	NSData *db_meta = [NSData dataWithBytesNoCopy:&meta length:sizeof(meta) freeWhenDone:NO];
	[db_meta writeToFile:metaPath atomically:NO];
	[db_crypt writeToFile:dbPath atomically:NO];

}

- (void)loadDB: (NSString *)db {
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
}

- (void)setDb: (NSString *)db {
	_db = db;
	[self loadDB:db];
	[_listview reloadData];
	[self writeDB:db];
}

- (void)viewDidLoad {
	[super viewDidLoad];
		
	// Load DB (manually, do not trigger write)
	_db = [self readDB];
	[self loadDB:_db];

	// Start periodic updates
	timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
	if (timer) {
		dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), 200*NSEC_PER_MSEC, 199*NSEC_PER_MSEC);
		dispatch_source_set_event_handler(timer, ^{
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

}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section > 0) {
		return 0;
	}
	return totps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	CodeCell *cell = [tableView dequeueReusableCellWithIdentifier:@"totp" forIndexPath:indexPath];
	cell.totp = totps[indexPath.row];
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	[(CodeCell *)cell refresh];
}

- (IBSegueAction DBEditorViewController *)editorSegue:(NSCoder *)coder sender:(id)sender {
	// Open
	DBEditorViewController *dst = [[DBEditorViewController alloc] initWithCoder:coder];
	dst.host = self;
	return dst;
}


@end
