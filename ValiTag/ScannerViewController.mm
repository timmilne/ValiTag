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
//  uGrokit RFID scanner code from:
//  http://dev.ugrokit.com/ios.html
//
//  Arete RFID scanner code from:
//  http://arete-mobile.com/arete_down.html

#import "ScannerViewController.h"
#import <AVFoundation/AVFoundation.h>   // Barcode capture tools
#import "DataClass.h"                   // Singleton data class
#import "EPCEncoder.h"                  // To encode the scanned barcode for comparison
#import "Converter.h"                   // To convert to binary for comparison
#import "Ugi.h"                         // uGrokit reader
#import "RcpApi2.h"                     // Arete reader
#import "AudioMgr.h"                    // Arete reader
#import "EpcConverter.h"                // Arete reader - converter

#pragma mark -
#pragma mark AVFoundationScanSetup

@interface ScannerViewController ()<AVCaptureMetadataOutputObjectsDelegate, UgiInventoryDelegate, RcpDelegate2>
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
    Converter                   *_convert;
    
    
    BOOL                        _ugiReaderConnected;
    UgiRfidConfiguration        *_ugiConfig;
    
    BOOL                        _areteReaderConnected;
    int                         _stopTagCount;
    int                         _stopTime;
    int                         _stopCycle;
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
// cplusplus stuff for Arete, and its C++ compiler
#ifdef __cplusplus
    self.navigationController.navigationBar.barStyle = static_cast<UIBarStyle>(UIStatusBarStyleLightContent);
#else
    self.navigationController.navigationBar.barStyle = UIStatusBarStyleLightContent;
#endif
    
    // Set the default background color
    [self.view setBackgroundColor:UIColorFromRGB(0x000000)];
    
    // Initialize and grab the data class
    data = [DataClass singleton:TRUE];
    
    // Reset
    _barcodeFound = FALSE;
    _rfidFound = FALSE;
   
// TPM: The barcode scanner example built the UI from scratch.  This made it easier to deal with all
// the settings programatically, so I've continued with that here...
    
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
    if (_convert == nil) _convert = [Converter alloc];
    
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
    
    // Set uGrokit scanner configuration used in startInventory
    _ugiReaderConnected = FALSE;
    _ugiConfig = [UgiRfidConfiguration configWithInventoryType:UGI_INVENTORY_TYPE_INVENTORY_SHORT_RANGE];
    [_ugiConfig setVolume:.2];
    
    // Set defaults for Arete scanner
    _areteReaderConnected = FALSE;
    _stopTagCount = 1;
    _stopTime = 0;
    _stopCycle = 0;
}

// Adjust the preview layer on orientation changes
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
  
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    switch ((int)orientation) {
        case UIInterfaceOrientationPortrait:
            [_prevLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            [_prevLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
            break;
        case UIInterfaceOrientationLandscapeLeft:
            [_prevLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
            break;
        case UIInterfaceOrientationLandscapeRight:
            [_prevLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
            break;
    }
}

// This for Arete
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // You can skip the rest, but this line is key
    [RcpApi2 sharedInstance].delegate = self;
    
#ifndef __IPHONE_7_0
    typedef void (^PermissionBlock)(BOOL granted);
#endif
    
    static BOOL bPermission = NO;
    
    PermissionBlock permissionBlock = ^(BOOL granted)
    {
        if (granted)
        {
            bPermission = YES;
        }
        else
        {
            // Warn no access to microphone
            UIAlertView *alert = [[UIAlertView alloc]
                                  initWithTitle:@"Error"
                                  message:@"Microphone input permission refused. Go to iOS settings to enable permission."
                                  delegate:nil
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
            
            dispatch_async(dispatch_get_main_queue(),
                           ^{
                               [alert show];
                           });
        }
    };
    
    if([[AVAudioSession sharedInstance] respondsToSelector:@selector(requestRecordPermission:)])
    {
        [[AVAudioSession sharedInstance] performSelector:@selector(requestRecordPermission:)
                                              withObject:permissionBlock];
    }
}

/**
 Reset the interface and reader and begin reading.
 
 Press the reset button after reading the first tag to read another.
 */
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
    
// TPM - This logic assumes that once you've read a tag with one type of reader, you won't switch
// to the other.  If you change readers, restart the app.  The first reader to scan a tag sets the
// reader flags for that session.  Until then, both protocols are attempted until a tag is found.
    
    // If no connection open, open it now and start scanning for RFID tags
    
    // Arete Reader (do this first to suppress a uGrokit bug)
    if (!_ugiReaderConnected) {
        [[RcpApi2 sharedInstance] stopReadTags];
        [[RcpApi2 sharedInstance] close];
        [[RcpApi2 sharedInstance] open];
        if ([[RcpApi2 sharedInstance] startReadTags:_stopTagCount mtime:_stopTime repeatCycle:_stopCycle]) {
            _rfidLbl.text = @"RFID: (scanning for tags)";
        }
    }

    // uGrokit Reader
    if (!_areteReaderConnected) {
        [[Ugi singleton].activeInventory stopInventory];
        [[Ugi singleton] closeConnection];
        [[Ugi singleton] openConnection];  // Once the reader is connected, this triggers the tag reads
        _rfidLbl.text = @"RFID: (connecting to reader)";
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/**
 Check the barcode and RFID tag for a match.
 
 Only called after both have been scanned.
 */
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

// Barcode scanner delegates
#pragma mark - Barcode Scanner

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

// uGrokit delegates
#pragma mark - uGrokit

/**
 New tag found with uGrokit reader.
 
 Display the tag, stop the reader, disable the other reader, and check for a match.
 */
- (void) inventoryTagFound:(UgiTag *)tag
   withDetailedPerReadData:(NSArray *)detailedPerReadData {
    // tag was found for the first time
    
    // Stop the RFID reader
    [[Ugi singleton].activeInventory stopInventory];
    
    // Get the RFID tag
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
    
    // After the first read, we know which reader
    _rfidFound = TRUE;
    if (!_ugiReaderConnected) {
        [[RcpApi2 sharedInstance] stopReadTags];
        [[RcpApi2 sharedInstance] close];
    }
    _ugiReaderConnected = TRUE;
    _areteReaderConnected = FALSE;
  
    // If we have a barcode and an RFID tag read, compare the results
    if (_barcodeFound && _rfidFound) [self checkForMatch];
}

/**
 State changed with uGrokit reader.
 
 Adjust to the new state, ignore if Arete reader being used.
 */
- (void)connectionStateChanged:(NSNotification *) notification {
    // This delegate conflicts with Arete's plugged call
    // If we are using the Arete reader, skip this
    if (_areteReaderConnected) return;
    
    // Listen for one of the following:
    //    UGI_CONNECTION_STATE_NOT_CONNECTED,        //!< Nothing connected to audio port
    //    UGI_CONNECTION_STATE_CONNECTING,           //!< Something connected to audio port, trying to connect
    //    UGI_CONNECTION_STATE_INCOMPATIBLE_READER,  //!< Connected to an reader with incompatible firmware
    //    UGI_CONNECTION_STATE_CONNECTED             //!< Connected to reader
    NSNumber *n = notification.object;
    
// cplusplus stuff for Arete, and C++ compiler
#ifdef __cplusplus
    UgiConnectionStates connectionState = static_cast<UgiConnectionStates>(n.intValue);
#else
    UgiConnectionStates connectionState = n.intValue;
#endif
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
        [[Ugi singleton] startInventory:self withConfiguration:_ugiConfig];
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

// Arete delegates
#pragma mark - Arete

/**
 New tag found with Arete reader.
 
 Display the tag, stop the reader, disable the other reader, and check for a match.
 */
- (void)tagReceived:(NSData*)pcEpc
{
    dispatch_async(dispatch_get_main_queue(),
                   ^{
                       // tag was found for the first time
                       
                       // Stop the RFID reader
                       [[RcpApi2 sharedInstance] stopReadTags];
                       
                       // Get the RFID tag
                       [data.rfid setString:([EpcConverter toHexString:pcEpc])];
                       [data.rfid setString:[data.rfid substringFromIndex:4]];
                       [data.rfidBin setString:[_convert Hex2Bin:data.rfid]];
                       _rfidLbl.text = [NSString stringWithFormat:@"RFID: %@", data.rfid];
                       _rfidLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
                       
                       // Get the serial number from the tag read
                       [data.ser setString:[_convert Bin2Dec:[data.rfidBin substringFromIndex:60]]];
                       
                       // Landscape label
                       _serLbl.text = [NSString stringWithFormat:@"Serial Num: %@", data.ser];
                       
                       // Close the connection
                       if ([[RcpApi2 sharedInstance] isOpened]) [[RcpApi2 sharedInstance] close];
                       
                       // After the first read, we know which reader
                       _rfidFound = TRUE;
                       if (!_areteReaderConnected) {
                           [[Ugi singleton].activeInventory stopInventory];
                           [[Ugi singleton] closeConnection];
                       }
                       _ugiReaderConnected = FALSE;
                       _areteReaderConnected = TRUE;
                       
                       // If we have a barcode and an RFID tag read, compare the results
                       if (_barcodeFound && _rfidFound) [self checkForMatch];
                   });
}

/*
- (void)tagWithRssiReceived:(NSData*)pcEpc rssi:(int8_t)rssi
{
    dispatch_async(dispatch_get_main_queue(),
                   ^{
                       NSString *tag = [EpcConverter toString:encoding_type data:pcEpc];
                       if(![self.tagViewController.tagIDArray containsObject:tag])
                       {
                           int tagCount = (int)([self.tagViewController.tagCountArray count] + 1);
                           [self.tagViewController.tagCountArray addObject:[NSNumber numberWithInt:(rssi)]];
                           //[self.tagViewController.tagIDArray addObject:pcEpc];
                           [self.tagViewController.tagIDArray addObject:tag];
                           self.olTagCount.text = [NSString stringWithFormat:@"%d",tagCount];
                       }
                       else
                       {
                           int index = (int)[self.tagViewController.tagIDArray indexOfObject:tag];
                           //int count = [[self.tagViewController.tagCountArray objectAtIndex:index] integerValue];
                           [self.tagViewController.tagCountArray
                            replaceObjectAtIndex:index                                                        withObject:[NSNumber numberWithInt:(rssi)]];
                       }    	
                       [self.tagViewController.tableView reloadData];
                   });
}
 */

/*
- (void)tagWithTidReceived:(NSData *)pcEpc tid:(NSData *)tid
{
}
 */

/**
 Reset received for Arete reader.
 
 This will be called by both readers until Arete disabled.
 */
- (void)resetReceived
{
    NSLog(@"resetReceived");
    dispatch_async(dispatch_get_main_queue(),
                   ^{
                       self->_rfidLbl.text = @"RFID: (scanning for tags)";
                       self->_rfidLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
                   });
}

- (void)successReceived:(uint8_t)commandCode
{
    NSLog(@"ack_received [%02X]\n",commandCode);
}

- (void)failureReceived:(NSData*)errCode
{
    NSLog(@"err_received [%02X]\n", ((const uint8_t *)errCode.bytes)[0]);
}

/**
 Set the battery life of the Arete reader.
 
 This delegate is called at random intervals.
 */
- (void)batteryStateReceived:(NSData*)data
{
    Byte *b = (Byte*) [data bytes];
    
    int adc = b[0];
    int adcMin = b[1];
    int adcMax = b[2];
    
    if(adcMin == adcMax)
    {
        adcMax += 1;
    }
    
    int battery = (adc-adcMin) * 100 / (adcMax - adcMin) + 12;
    battery /= 25;
    battery *= 25;
    
    if(battery > 100) battery = 100;
    else if(battery < 0) battery = 0;

    dispatch_async(dispatch_get_main_queue(),
                   ^{
                       _batteryLifeView.progress = battery/100.;
                       _batteryLifeLbl.backgroundColor =
                       (battery > 20)?UIColorFromRGB(0xA4CD39):
                       (battery > 5 )?UIColorFromRGB(0xCC9900):
                       UIColorFromRGB(0xCC0000);
                       
                       _batteryLifeLbl.text = [NSString stringWithFormat:@"RFID Battery Life: %d%%", battery];
                   });
}

/**
 Somthing was plugged into the audio jack (Arete reader).
 
 Start reading tags, ignore if Arete reader being used.
 */
- (void)plugged:(BOOL)plug
{
    // This delegate conflicts with uGrokit's connectionStateChanged call
    // If we are using the uGrokit reader, skip this
    if (_ugiReaderConnected) return;
    
    if(plug)
    {
        _rfidLbl.text = @"RFID: (scanning for tags)";
        _rfidLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
        
        if([[RcpApi2 sharedInstance] open]) {
            [[RcpApi2 sharedInstance] startReadTags:_stopTagCount mtime:_stopTime repeatCycle:_stopCycle];
        }
    }
    else
    {
        // This gets called after a tag is read and the connection closed
        // The label and the rfid flag have already been set in tagReceived
        // Don't do anything here
    }
}

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
