//
//  CodeCell.m
//  totp
//
//  Created by Fang Lu on 9/16/23.
//

#import "CodeCell.h"

@interface CodeCell ()

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *codeLabel;
@property (weak, nonatomic) IBOutlet UILabel *timerLabel;

@end

@implementation CodeCell

short _digits = 6, _period = 30;
NSString *_tfmt = @"(%02d)";
NSString *_cfmt = @"%06d";

@synthesize code = _code;
@synthesize timer = _timer;
@synthesize totp = _totp;
@synthesize digits = _digits;
@synthesize period = _period;

- (void)setLabel:(NSString *)label {
	_titleLabel.text = label;
}

- (NSString *)label {
	return _titleLabel.text;
}

- (void) setCode:(NSString *)code {
	if (code != _code) {
		_code = code;
		_codeLabel.text = [NSString stringWithFormat:_cfmt, code];
	}
}

- (void)setTimer:(int)timer {
	if (timer != _timer) {
		if ((timer > 5) != (_timer > 5)) {
			// Change color
			UIColor *color = (timer > 5) ? UIColor.blackColor : UIColor.redColor;
			_titleLabel.textColor = color;
			_codeLabel.textColor = color;
			_timerLabel.textColor = color;
		}
		_timerLabel.text = [NSString stringWithFormat:_tfmt, timer];
		_timer = timer;
	}
}

- (void)setDigits:(short)digits {
	if (digits != _digits) {
		_digits = digits;
		_cfmt = [NSString stringWithFormat:@"%%0%dd", digits];
	}
}

- (void)setPeriod:(short)period {
	if (period != _period) {
		_period = period;
		long digits = [NSNumber numberWithShort:period].stringValue.length;
		_tfmt = [NSString stringWithFormat:@"(%%0%ldd)", digits];
	}
}

- (void)setTotp:(ObjTOTP *)totp {
	_totp = totp;
	self.label = totp.name;
	self.digits = totp.digits;
	self.period = totp.period;
}

- (void)refresh {
	if (!_totp) {
		return;
	}
	time_t t = time(NULL);
	_codeLabel.text = [NSString stringWithFormat:_cfmt, [_totp getCodeAtTime:t]];
	self.timer = _period - (t % _period);
	
}

@end
