//
//  ScannerViewController.m
//  ValiTag
//
//  Created by Tim.Milne on 4/28/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//
//  This from:
//  http://www.infragistics.com/community/blogs/torrey-betts/archive/2013/10/10/scanning-barcodes-with-ios-7-objective-c.aspx
//

#import <AVFoundation/AVFoundation.h>
#import "ScannerViewController.h"
#import "DataClass.h" // Singleton data class
#import "Ugi.h"

@interface ScannerViewController ()<AVCaptureMetadataOutputObjectsDelegate, UgiInventoryDelegate>
{
    BOOL _barcodeFound;
    BOOL _rfidFound;
    
    AVCaptureSession *_session;
    AVCaptureDevice *_device;
    AVCaptureDeviceInput *_input;
    AVCaptureMetadataOutput *_output;
    AVCaptureVideoPreviewLayer *_prevLayer;
    
    UIView *_highlightView;
    UILabel *_barcode;
    
    UgiInventory *_inventory;
}

@end

// The global data class
extern DataClass *data;

@implementation ScannerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Grab the data class
    if (data == nil) data = [DataClass getInstance:TRUE];
    
    // Reset
    _barcodeFound = FALSE;
    _rfidFound = FALSE;

    _highlightView = [[UIView alloc] init];
    _highlightView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
    _highlightView.layer.borderColor = [UIColor greenColor].CGColor;
    _highlightView.layer.borderWidth = 3;
    [self.view addSubview:_highlightView];
    
    _barcode = [[UILabel alloc] init];
    _barcode.frame = CGRectMake(0, self.view.bounds.size.height - 40, self.view.bounds.size.width, 40);
    _barcode.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _barcode.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _barcode.textColor = [UIColor whiteColor];
    _barcode.textAlignment = NSTextAlignmentCenter;
    _barcode.text = @"(none)";
    [self.view addSubview:_barcode];
    
    _session = [[AVCaptureSession alloc] init];
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    
    _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:&error];
    if (_input) {
        [_session addInput:_input];
    } else {
        NSLog(@"Error: %@", error);
    }
    
    _output = [[AVCaptureMetadataOutput alloc] init];
    [_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [_session addOutput:_output];
    
    _output.metadataObjectTypes = [_output availableMetadataObjectTypes];
    
    _prevLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    _prevLayer.frame = self.view.bounds;
    _prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:_prevLayer];
    
    [_session startRunning];
    
    [self.view bringSubviewToFront:_highlightView];
    [self.view bringSubviewToFront:_barcode];

    
/*
    // Register with the default NotificationCenter
    // TPM this was a typo in the online documentation
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                        selector:@selector(connectionStateChanged:)
//                                        name:UGROKIT_NOTIFICAION_NAME_CONNECTION_STATE_CHANGED
//                                        object:nil];
    // This one compiled, I'm not getting any messages...
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(connectionStateChanged:)
                                            name:[Ugi singleton].NOTIFICAION_NAME_CONNECTION_STATE_CHANGED
                                            object:nil];
*/
    
    // Now, in the background, start scanning for RFID tags
    [[Ugi singleton] openConnection];


    // When a tag is found, the inventoryTagFound delegate will be called
    _inventory = [[Ugi singleton] startInventory:self    // delegate object
                    withConfiguration:[UgiRfidConfiguration
                    configWithInventoryType:UGI_INVENTORY_TYPE_LOCATE_DISTANCE]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    CGRect highlightViewRect = CGRectZero;
    AVMetadataMachineReadableCodeObject *barCodeObject;
    NSString *detectionString = nil;
    NSArray *barCodeTypes = @[AVMetadataObjectTypeUPCECode, AVMetadataObjectTypeCode39Code, AVMetadataObjectTypeCode39Mod43Code,
                              AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode93Code, AVMetadataObjectTypeCode128Code,
                              AVMetadataObjectTypePDF417Code, AVMetadataObjectTypeQRCode, AVMetadataObjectTypeAztecCode];
    
    for (AVMetadataObject *metadata in metadataObjects) {
        for (NSString *type in barCodeTypes) {
            if ([metadata.type isEqualToString:type])
            {
                barCodeObject = (AVMetadataMachineReadableCodeObject *)[_prevLayer transformedMetadataObjectForMetadataObject:(AVMetadataMachineReadableCodeObject *)metadata];
                highlightViewRect = barCodeObject.bounds;
                detectionString = [(AVMetadataMachineReadableCodeObject *)metadata stringValue];
                break;
            }
        }
        
        if (detectionString != nil)
        {
            _barcode.text = detectionString;
            [data.barcode setString:detectionString];
            _barcodeFound = TRUE;
            break;
        }
        else
            _barcode.text = @"(none)";
    }
    
    _highlightView.frame = highlightViewRect;
    
    // Check to see if an RFID reader is connected
    if (![Ugi singleton].isConnected) {
        // Just ignore the RFID reads
        [data.rfid setString:@"No Reader Found"];
        _rfidFound = TRUE;
    }

    // If we have a barcode and an RFID tag read, unwind and compare the results
    if (_barcodeFound && _rfidFound) {
        [self performSegueWithIdentifier:@"unwindToContainerVC" sender:self];
    }
}

// Here are the uGrokit delegates that can be implemented

// New tag found
- (void) inventoryTagFound:(UgiTag *)tag
   withDetailedPerReadData:(NSArray *)detailedPerReadData {
    // tag was found for the first time
    
    // Stop the RFID reader
    [[Ugi singleton].activeInventory stopInventory];
    
    // Get the RFID tag2
    [data.rfid setString:[tag.epc toString]];
    
    // Close the connection
    [[Ugi singleton] closeConnection];
    
    _rfidFound = TRUE;
  
    // If we have a barcode and an RFID tag read, unwind and compare the results
    if (_barcodeFound && _rfidFound) {
        [self performSegueWithIdentifier:@"unwindToContainerVC" sender:self];
    }
}

// TPM This isn't being called....
// See the registration code in viewDidLoad...
/*
// State changed method
- (void)connectionStateChanged:(NSNotification *) notification {
    // Listen for one of the following:
    //    UGI_CONNECTION_STATE_NOT_CONNECTED,        //!< Nothing connected to audio port
    //    UGI_CONNECTION_STATE_CONNECTING,           //!< Something connected to audio port, trying to connect
    //    UGI_CONNECTION_STATE_INCOMPATIBLE_READER,  //!< Connected to an reader with incompatible firmware
    //    UGI_CONNECTION_STATE_CONNECTED             //!< Connected to reader
    NSNumber *n = notification.object;
    UgiConnectionStates connectionState = n.intValue;
    if (connectionState == UGI_CONNECTION_STATE_CONNECTED) {
        // Connection was established...
    }
    if (connectionState == UGI_CONNECTION_STATE_NOT_CONNECTED ||
        connectionState == UGI_CONNECTION_STATE_INCOMPATIBLE_READER) {
        // Just ignore the RFID reads
        [data.rfid setString:@"No Reader Found"];
        _rfidFound = TRUE;
    }
}
*/

/*
// Subsequent finds of previously found tag
- (void) inventoryTagSubsequentFinds:(UgiTag *)tag numFinds:(int)num
             withDetailedPerReadData:(NSArray *)detailedPerReadData {
    // tag found count more times
}
*/

/*
// Tag visibility changed
- (void) inventoryTagChanged:(UgiTag *)tag isFirstFind:(BOOL)firstFind {
    if (firstFind) {
        // tag was found for the first time
    } else if (tag.isVisible) {
        // tag was not visible, is now visible again
    } else {
        // tag is no longer visible
    }
}
*/

/*
// Tag filtering
- (BOOL) inventoryFilterTag:(UgiTag *)tag {
    if (this tag should be ignored) {
        return YES;
    } else {
        return NO;
    }
}
*/

/*
// List of found tags
// While inventory is running, the app can access the list of found tags via the tags property of the UgiInventory object.
// @property (readonly, retain) NSArray *tags;
// Usage is typically:
for (UgiTag *tag in [Ugi singleton].activeInventory.tags) {
    // do something with tag
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
