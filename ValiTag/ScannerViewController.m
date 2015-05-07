
//
//  ScannerViewController.m
//  ValiTag
//
//  Created by Tim.Milne on 4/28/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//
//  Barcode scanner code from:
//  http://www.infragistics.com/community/blogs/torrey-betts/archive/2013/10/10/scanning-barcodes-with-ios-7-objective-c.aspx
//
//  RFID scanner code from:
//  http://dev.ugrokit.com/ios.html
//

#import <AVFoundation/AVFoundation.h>   // Barcode capture tools
#import "ScannerViewController.h"
#import "DataClass.h"                   // Singleton data class
#import "Ugi.h"                         // uGrokit goodies
#import "EPCEncoder.h"                  // To encode the scanned barcode for comparison
#import "EPCConverter.h"                // To convert to binary for comparison

#pragma mark -
#pragma mark AVFoundationScanSetup

@interface ScannerViewController ()<AVCaptureMetadataOutputObjectsDelegate, UgiInventoryDelegate>
{
    __weak IBOutlet UIImageView *_matchView;
    __weak IBOutlet UIImageView *_noMatchView;
    
    BOOL _barcodeFound;
    BOOL _rfidFound;
    
    AVCaptureSession *_session;
    AVCaptureDevice *_device;
    AVCaptureDeviceInput *_input;
    AVCaptureMetadataOutput *_output;
    AVCaptureVideoPreviewLayer *_prevLayer;
    
    UIView *_highlightView;
    UILabel *_barcodeLbl;
    UILabel *_rfidLbl;
    UILabel *_batteryLifeLbl;
    UIProgressView *_batteryLifeView;
    
    EPCEncoder *_encode;
    EPCConverter *_convert;
    
    UgiRfidConfiguration *_config;
}

@end

// The singleton data class
extern DataClass *data;

@implementation ScannerViewController

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:0.65]

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set the status bar to white (iOS bug)
    // Also had to add the statusBarStyle entry to info.plist
    self.navigationController.navigationBar.BarStyle = UIStatusBarStyleLightContent;
    
    // Initialize and grab the data class
    data = [DataClass singleton:TRUE];
    
    // Reset
    _barcodeFound = FALSE;
    _rfidFound = FALSE;
   
    // TPM: The barcode scanner example built the UI from scratch.  This made it easier to deal with all
    // the setting programatically, so I've continued with that here...
    // Barcode highlight view
    _highlightView = [[UIView alloc] init];
    _highlightView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
    _highlightView.layer.borderColor = [UIColor greenColor].CGColor;
    _highlightView.layer.borderWidth = 3;
    [self.view addSubview:_highlightView];
    
    // Barcode label view
    _barcodeLbl = [[UILabel alloc] init];
    _barcodeLbl.frame = CGRectMake(0, self.view.bounds.size.height - 120, self.view.bounds.size.width, 40);
    _barcodeLbl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _barcodeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _barcodeLbl.textColor = [UIColor whiteColor];
    _barcodeLbl.textAlignment = NSTextAlignmentCenter;
    _barcodeLbl.text = @"Barcode: (scanning for barcodes)";
    [self.view addSubview:_barcodeLbl];
    
    // RFID label view
    _rfidLbl = [[UILabel alloc] init];
    _rfidLbl.frame = CGRectMake(0, self.view.bounds.size.height - 80, self.view.bounds.size.width, 40);
    _rfidLbl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _rfidLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _rfidLbl.textColor = [UIColor whiteColor];
    _rfidLbl.textAlignment = NSTextAlignmentCenter;
    _rfidLbl.text = @"RFID: (connecting to reader)";
    [self.view addSubview:_rfidLbl];
    
    // Initialize the bar code scanner session, device, input, output, and preview layer
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
    
    // Start scanning for barcodes
    [_session startRunning];

    // Pop the subviews to the front
    [self.view bringSubviewToFront:_highlightView];
    [self.view bringSubviewToFront:_barcodeLbl];
    
    // Initiliaze the encoder and convert
    if (_encode == nil) _encode = [EPCEncoder alloc];
    if (_convert == nil) _convert = [EPCConverter alloc];
    
    // Register with the default NotificationCenter
    // TPM there was a typo in the online documentation fixed here
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(connectionStateChanged:)
                                            name:[Ugi singleton].NOTIFICAION_NAME_CONNECTION_STATE_CHANGED
                                            object:nil];
    
    // Connect to the scanner
    // When notified that the connection is established, get the battery life, and start a scan
    [[Ugi singleton] openConnection];
    
    // RFID label
    _batteryLifeLbl = [[UILabel alloc] init];
    _batteryLifeLbl.frame = CGRectMake(0, self.view.bounds.size.height - 40, self.view.bounds.size.width, 40);
    _batteryLifeLbl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _batteryLifeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _batteryLifeLbl.textColor = [UIColor whiteColor];
    _batteryLifeLbl.textAlignment = NSTextAlignmentCenter;
    _batteryLifeLbl.text = @"RFID Battery Life";
    [self.view addSubview:_batteryLifeLbl];
    
    // Battery life label
    _batteryLifeView = [[UIProgressView alloc] init];
    _batteryLifeView.frame = CGRectMake(0, self.view.bounds.size.height - 8, self.view.bounds.size.width, 40);
    _batteryLifeView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _batteryLifeView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    [self.view addSubview:_batteryLifeView];
    
    // Pop the subviews to the front
    [self.view bringSubviewToFront:_rfidLbl];
    [self.view bringSubviewToFront:_batteryLifeLbl];
    [self.view bringSubviewToFront:_batteryLifeView];
    
    // Set scanner configuration used in startInventory
    _config = [UgiRfidConfiguration configWithInventoryType:UGI_INVENTORY_TYPE_INVENTORY_SHORT_RANGE];
    [_config setVolume:.2];
}

- (IBAction)reset:(id)sender {
    // Reset
    data = [DataClass singleton:TRUE];
    _barcodeFound = FALSE;
    _rfidFound = FALSE;
    _barcodeLbl.text = @"Barcode: (scanning for barcodes)";
    _rfidLbl.text = @"RFID: (connecting to reader)";
    _barcodeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _rfidLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _batteryLifeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    [self.view sendSubviewToBack:_matchView];
    [self.view sendSubviewToBack:_noMatchView];
    
    // If no connection open, open it now and start scanning for RFID tags
    [[Ugi singleton].activeInventory stopInventory];
    [[Ugi singleton] closeConnection];
    [[Ugi singleton] openConnection];
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
            // Tell the uGrokit to beep...
            
            // Grab the barcode
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@", detectionString];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
            
            // Now, take the dpt, cls and itm, and encode a reference
            NSString *barcode;
            barcode = detectionString;

            if (barcode.length == 13) barcode = [barcode substringFromIndex:1];
            if (barcode.length == 14) barcode = [barcode substringFromIndex:2];
            NSString *mnf = [barcode substringToIndex:2];
            if (barcode.length == 12 && [mnf isEqualToString:@"49"]) {
                NSRange dptRange = {2, 3};
                NSRange clsRange = {5, 2};
                NSRange itmRange = {7, 4};
                NSString *dpt = [barcode substringWithRange:dptRange];
                NSString *cls = [barcode substringWithRange:clsRange];
                NSString *itm = [barcode substringWithRange:itmRange];
                NSString *ser = @"0";
                
                [_encode withDpt:dpt cls:cls itm:itm ser:ser];
                
                [data.barcode setString:detectionString];
                [data.encodedBarcode setString:[_encode gid_hex]];
                [data.encodedBarcodeBin setString:[_convert Hex2Bin:data.encodedBarcode]];
                [data.dpt setString:dpt];
                [data.cls setString:cls];
                [data.itm setString:itm];
            }
            else {
                //Unsupported barcode
                [data.barcode setString:@"unsupported barcode"];
                [data.encodedBarcode setString:@"unsupported barcode"];
                [data.encodedBarcodeBin setString:@"unsupported barcode"];
                [data.dpt setString:@""];
                [data.cls setString:@""];
                [data.itm setString:@""];
            }
            
            _barcodeFound = TRUE;
        }
        else
            _barcodeLbl.text = @"Barcode: (scanning for barcodes)";
    }
    
    _highlightView.frame = highlightViewRect;

    // If we have a barcode and an RFID tag read, compare the results
    if (_barcodeFound && _rfidFound) [self checkForMatch];
}

- (void)checkForMatch {
    // Compare the binary formats
    if ([data.rfidBin length] > 60 && [data.encodedBarcodeBin length] > 60 &&
        [[data.rfidBin substringToIndex:59] isEqualToString:[data.encodedBarcodeBin substringToIndex:59]]) {
        // Match: hide the no match and show the match
        [self.view bringSubviewToFront:_matchView];
        [self.view sendSubviewToBack:_noMatchView];
        _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
        _rfidLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
    }
    else {
        // No match: hide the match and show the no match
        [self.view bringSubviewToFront:_noMatchView];
        [self.view sendSubviewToBack:_matchView];
        _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
        _rfidLbl.backgroundColor = UIColorFromRGB(0xCC0000);
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
    [data.rfidBin setString:[_convert Hex2Bin:data.rfid]];
    _rfidLbl.text = [NSString stringWithFormat:@"RFID: %@", data.rfid];
    _rfidLbl.backgroundColor = UIColorFromRGB(0xA4CD39);

    // Get the serial number from the tag read
    [data.ser setString:[_convert Bin2Dec:[data.rfidBin substringFromIndex:60]]];
    
    // Close the connection
    [[Ugi singleton] closeConnection];
    
    _rfidFound = TRUE;
  
    // If we have a barcode and an RFID tag read, compare the results
    if (_barcodeFound && _rfidFound) [self checkForMatch];
}

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
        // Update the battery life with a new connection before starting an inventory
        UgiBatteryInfo batteryInfo;
        if ([[Ugi singleton] getBatteryInfo:&batteryInfo]) {
            _batteryLifeView.progress = batteryInfo.percentRemaining;
            _batteryLifeLbl.backgroundColor =
                (batteryInfo.percentRemaining > .2)? UIColorFromRGB(0xA4CD39):
                (batteryInfo.percentRemaining > .05)?UIColorFromRGB(0xCC9900):
                                                     UIColorFromRGB(0xCC0000);
        }
        
        // Start scanning for RFID tags - when a tag is found, the inventoryTagFound delegate will be called
        _rfidLbl.text = @"RFID: (scanning for tags)";
        [[Ugi singleton] startInventory:self withConfiguration:_config];
        return;
    }
    if (connectionState == UGI_CONNECTION_STATE_CONNECTING) {
        _rfidLbl.text = @"RFID: (connecting to reader)";
        return;
    }
    if (connectionState == UGI_CONNECTION_STATE_INCOMPATIBLE_READER) {
        // With no reader, just ignore the RFID reads
        [data.rfid setString:@"RFID: no reader found"];
        _rfidLbl.backgroundColor = UIColorFromRGB(0xCC0000);
        _rfidFound = TRUE;
        return;
    }
    if (connectionState == UGI_CONNECTION_STATE_NOT_CONNECTED ) {
        // This gets called after a tag is read and the connection closed
        // The label and the rfid flag have already been set in inventoryTagFound
        // Don't do anything here
        return;
    }
}

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
    
    // Stop the RFID reader
    [[Ugi singleton].activeInventory stopInventory];
}
 */

- (IBAction)unwindToContainerVC:(UIStoryboardSegue *)segue {
    // Used for swipe gestures, but can't get this working with my new VC    
}

@end
