//
//  TOTPEditorViewController.m
//  totp
//
//  Created by Fang Lu on 9/18/23.
//

#import "TOTPEditorViewController.h"

@interface TOTPEditorViewController ()
@property (weak, nonatomic) IBOutlet UITextField *urlField;
@property (weak, nonatomic) IBOutlet UIView *qrview;

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;

@end

@implementation TOTPEditorViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view.
	if (_totp) {
		_urlField.text = _totp.url;
	} else {
		[self startReading];
	}
}

- (BOOL)startReading {
	NSError *error;
	
	AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	
	AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
	if (!input) {
		NSLog(@"%@", [error localizedDescription]);
		return NO;
	}
	
	_captureSession = [[AVCaptureSession alloc] init];
	[_captureSession addInput:input];
	
	AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
	[_captureSession addOutput:captureMetadataOutput];
	
	dispatch_queue_t dispatchQueue;
	dispatchQueue = dispatch_queue_create("myQueue", NULL);
	[captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
	[captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
	
	_videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
	[_videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
	[_videoPreviewLayer setFrame:_qrview.layer.bounds];
	[_qrview.layer addSublayer:_videoPreviewLayer];
	
	[_captureSession startRunning];
	
	return YES;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
	if (!metadataObjects) {
		return;
	}
	for (AVMetadataMachineReadableCodeObject *metadataObj in metadataObjects) {
		if ([[metadataObj type] isEqualToString:AVMetadataObjectTypeQRCode]) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[self scannedURL:metadataObj.stringValue];
			});
		}
	}
}

- (void)scannedURL: (NSString *)url {
	_totp.url = url;
	_urlField.text = url;
}
@end
