
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

#import "ScannerViewController.h"
#import <AVFoundation/AVFoundation.h>   // Barcode capture tools
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
    __weak IBOutlet UILabel     *_dptLbl;
    __weak IBOutlet UILabel     *_clsLbl;
    __weak IBOutlet UILabel     *_itmLbl;
    __weak IBOutlet UILabel     *_serLbl;
    __weak IBOutlet UILabel     *_encodedBarcodeLbl;
    
    BOOL                        _barcodeFound;
    BOOL                        _rfidFound;
    
    AVCaptureSession            *_session;
    AVCaptureDevice             *_device;
    AVCaptureDeviceInput        *_input;
    AVCaptureMetadataOutput     *_output;
    AVCaptureVideoPreviewLayer  *_prevLayer;
    
    UIView                      *_highlightView;
    UILabel                     *_barcodeLbl;
    UILabel                     *_rfidLbl;
    UILabel                     *_batteryLifeLbl;
    UIProgressView              *_batteryLifeView;
    
    EPCEncoder                  *_encode;
    EPCConverter                *_convert;
    
    UgiRfidConfiguration        *_config;
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
    self.navigationController.navigationBar.barStyle = UIStatusBarStyleLightContent;
    
    // Set the default background color
    [self.view setBackgroundColor:UIColorFromRGB(0x000000)];
    
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
    
    // Initiliaze the encoder and converter
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
    _batteryLifeLbl.text = @"RFID Battery Life";
    _barcodeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _rfidLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _batteryLifeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _batteryLifeView.progress = 0.;
    
    // Landscape labels
    _dptLbl.text = @"Department: ";
    _clsLbl.text = @"Class: ";
    _itmLbl.text = @"Item: ";
    _serLbl.text = @"Serial Num: ";
    _encodedBarcodeLbl.text = @"(scanning for barcodes)";
    [self.view setBackgroundColor:UIColorFromRGB(0x000000)];
    
    //Match images
    [self.view sendSubviewToBack:_matchView];
    [self.view sendSubviewToBack:_noMatchView];
    _matchView.hidden = YES;
    _noMatchView.hidden = YES;
    
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
            NSString *barcode;
            barcode = detectionString;

            // Quick length checks, chop to 12 for now (remove leading zeros)
            if (barcode.length == 13) barcode = [barcode substringFromIndex:1];
            if (barcode.length == 14) barcode = [barcode substringFromIndex:2];
            
            // Owned brand, check against the DPCI encoded in a GID
            if (barcode.length == 12 && [[barcode substringToIndex:2] isEqualToString:@"49"]) {
                NSString *dpt = [barcode substringWithRange:NSMakeRange(2,3)];
                NSString *cls = [barcode substringWithRange:NSMakeRange(5,2)];
                NSString *itm = [barcode substringWithRange:NSMakeRange(7,4)];
                NSString *ser = @"0";
                
                [_encode withDpt:dpt cls:cls itm:itm ser:ser];
                
                [data.barcode setString:detectionString];
                [data.encodedBarcode setString:[_encode gid_hex]];
                [data.encodedBarcodeBin setString:[_convert Hex2Bin:data.encodedBarcode]];
                [data.dpt setString:dpt];
                [data.cls setString:cls];
                [data.itm setString:itm];
            }
            
            // National brand, check against GTIN (barcode) encoded in SGTIN
            else if (([data.rfidBin length] > 0) &&
                     ([[data.rfidBin substringToIndex:8] isEqualToString:SGTIN_Bin_Prefix]) &&
                     ((barcode.length == 12) || (barcode.length == 14))) {
                
                [_encode withGTIN:barcode ser:@"0" partBin:[data.rfidBin substringWithRange:NSMakeRange(11,3)]];
                
                [data.barcode setString:detectionString];
                [data.encodedBarcode setString:[_encode sgtin_hex]];
                [data.encodedBarcodeBin setString:[_convert Hex2Bin:data.encodedBarcode]];
                [data.dpt setString:@""];
                [data.cls setString:@""];
                [data.itm setString:@""];
            }
            
            //Unsupported barcode
            else {
                [data.barcode setString:@"unsupported barcode"];
                [data.encodedBarcode setString:@"unsupported barcode"];
                [data.encodedBarcodeBin setString:@"unsupported barcode"];
                [data.dpt setString:@""];
                [data.cls setString:@""];
                [data.itm setString:@""];
            }
            
            // Landscape labels
            _dptLbl.text = [NSString stringWithFormat:@"Department: %@", data.dpt];
            _clsLbl.text = [NSString stringWithFormat:@"Class: %@", data.cls];
            _itmLbl.text = [NSString stringWithFormat:@"Item: %@", data.itm];
            _encodedBarcodeLbl.text = data.encodedBarcode;
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
    // Compare the binary formats: SGTIN = 58, GID = 60
    int length = ([[data.rfidBin substringToIndex:8] isEqualToString:SGTIN_Bin_Prefix])?58:60;
    if ([data.rfidBin length] > length && [data.encodedBarcodeBin length] > length &&
        [[data.rfidBin substringToIndex:(length-1)] isEqualToString:[data.encodedBarcodeBin substringToIndex:(length-1)]]) {
        // Match: hide the no match and show the match
        [self.view bringSubviewToFront:_matchView];
        [self.view sendSubviewToBack:_noMatchView];
        _matchView.hidden = NO;
        _noMatchView.hidden = YES;
        _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
        _rfidLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
        [self.view setBackgroundColor:UIColorFromRGB(0xA4CD39)];
    }
    else {
        // No match: hide the match and show the no match
        [self.view bringSubviewToFront:_noMatchView];
        [self.view sendSubviewToBack:_matchView];
        _matchView.hidden = YES;
        _noMatchView.hidden = NO;
        _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
        _rfidLbl.backgroundColor = UIColorFromRGB(0xCC0000);
        [self.view setBackgroundColor:UIColorFromRGB(0xCC0000)];
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
    
    // Landscape label
    _serLbl.text = [NSString stringWithFormat:@"Serial Num: %@", data.ser];
    
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
            _batteryLifeView.progress = (batteryInfo.percentRemaining)/100.;
            _batteryLifeLbl.backgroundColor =
                (batteryInfo.percentRemaining > 20)?UIColorFromRGB(0xA4CD39):
                (batteryInfo.percentRemaining > 5 )?UIColorFromRGB(0xCC9900):
                                                    UIColorFromRGB(0xCC0000);
            
            _batteryLifeLbl.text = [NSString stringWithFormat:@"RFID Battery Life: %d%%", batteryInfo.percentRemaining];
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
