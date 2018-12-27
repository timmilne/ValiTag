//
//  ScannerViewController.m
//  ValiTag
//
//  Created by Tim.Milne on 4/28/15.
//  Copyright (c) 2015, 2019 Tim.Milne. All rights reserved.
//
//  Barcode scanner code from:
//  http://www.infragistics.com/community/blogs/torrey-betts/archive/2013/10/10/scanning-barcodes-with-ios-7-objective-c.aspx
//
//  uGrokit RFID scanner code from:
//  http://dev.ugrokit.com/ios.html
//
//  Zebra RFID scanner code from:
//  http://compass.motorolasolutions.com

#import "ScannerViewController.h"
#import <AVFoundation/AVFoundation.h>   // Barcode capture tools
#import <EPCEncoder/EPCEncoder.h>       // To encode the scanned barcode for comparison
#import <EPCEncoder/Converter.h>        // To convert to binary for comparison
#import "CheckDataObject.h"             // Singleton check data object class
#import "Ugi.h"                         // uGrokit reader
#import "RfidSdkFactory.h"              // Zebra reader
#import "AppDelegate.h"                 // The app delegate

#pragma mark -
#pragma mark AVFoundationScanSetup

@interface ScannerViewController ()<AVCaptureMetadataOutputObjectsDelegate, UgiInventoryDelegate, srfidISdkApiDelegate, NSFilePresenter>
{
    __weak IBOutlet UIImageView *_matchView;
    __weak IBOutlet UIImageView *_noMatchView;
    __weak IBOutlet UILabel     *_dptLbl;
    __weak IBOutlet UILabel     *_clsLbl;
    __weak IBOutlet UILabel     *_itmLbl;
    __weak IBOutlet UILabel     *_serLbl;
    __weak IBOutlet UILabel     *_encodedBarcodeLbl;
    __weak IBOutlet UIButton    *_saveValidTagBtn;      // To save the validated tag
    
    BOOL                        _barcodeFound;
    BOOL                        _barcodeProcessed;
    BOOL                        _rfidFound;
    NSMutableString             *_lastDetectionString;
    
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
    
    BOOL                        _zebraReaderConnected;
    id <srfidISdkApi>           _rfidSdkApi;
    int                         _zebraReaderID;
    srfidStartTriggerConfig     *_startTriggerConfig;
    srfidStopTriggerConfig      *_stopTriggerConfig;
    srfidReportConfig           *_reportConfig;
    srfidAccessConfig           *_accessConfig;
}
@end

// The singleton check data object
extern CheckDataObject *checkData;

@implementation ScannerViewController

// NSFilePresenter
@synthesize presentedItemOperationQueue;
@synthesize presentedItemURL;

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:0.65]

#define MyAppDelegate ((AppDelegate *)[UIApplication sharedApplication].delegate)

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set the status bar to white (iOS bug)
    // Also had to add the statusBarStyle entry to info.plist
    self.navigationController.navigationBar.barStyle = UIStatusBarStyleLightContent;
    
    // Set the default background color
    [self.view setBackgroundColor:UIColorFromRGB(0x000000)];
    
    // Initialize and grab the singleton check data object
    checkData = [CheckDataObject singleton:TRUE];
    
    // Initialize variables
    _lastDetectionString = [[NSMutableString alloc] init];
    _barcodeFound = FALSE;
    _barcodeProcessed = FALSE;
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
    
    // Battery life label
    _batteryLifeLbl = [[UILabel alloc] init];
    _batteryLifeLbl.frame = CGRectMake(0, self.view.bounds.size.height - 40, self.view.bounds.size.width, 40);
    _batteryLifeLbl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _batteryLifeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _batteryLifeLbl.textColor = [UIColor whiteColor];
    _batteryLifeLbl.textAlignment = NSTextAlignmentCenter;
    _batteryLifeLbl.text = @"RFID Battery Life";
    [self.view addSubview:_batteryLifeLbl];
    
    // Battery life view
    _batteryLifeView = [[UIProgressView alloc] init];
    _batteryLifeView.frame = CGRectMake(0, self.view.bounds.size.height - 8, self.view.bounds.size.width, 40);
    _batteryLifeView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _batteryLifeView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    [self.view addSubview:_batteryLifeView];
    
    // Initialize the bar code scanner session, device, input, output, and preview layer
    _session = [[AVCaptureSession alloc] init];
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:&error];
    if (_input) {
        [_session addInput:_input];
    } else {
        NSLog(@"Error: %@\n", error);
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
    
    // Pop the subviews to the front
    [self.view bringSubviewToFront:_rfidLbl];
    [self.view bringSubviewToFront:_batteryLifeLbl];
    [self.view bringSubviewToFront:_batteryLifeView];
    
    // Set uGrokit scanner configuration used in startInventory
    _ugiReaderConnected = FALSE;
    _ugiConfig = [UgiRfidConfiguration configWithInventoryType:UGI_INVENTORY_TYPE_INVENTORY_SHORT_RANGE];
    [_ugiConfig setVolume:.2];
    
    // Set Zebra scanner configurations used in srfidStartRapidRead
    _zebraReaderConnected = FALSE;
    _zebraReaderID = -1;
    [self zebraInitializeRfidSdkWithAppSettings];
}

/*!
 * @discussion Adjust the preview layer on orientation changes
 */
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
    _saveValidTagBtn.frame = CGRectMake(_prevLayer.frame.size.width - 4 - 26,
                                        self.view.bounds.size.height - 120 - 10 - 26,
                                        26, 26);
}

/*!
 * @discussion Press reset button to reset the interface and reader and begin reading.
 * @param sender An id for the sender control (not used)
 */
- (IBAction)reset:(id)sender {
    // Reset
    checkData = [CheckDataObject singleton:TRUE];
    _barcodeFound = FALSE;
    _barcodeProcessed = FALSE;
    _rfidFound = FALSE;
    [_lastDetectionString setString:@""];
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
    [self.view sendSubviewToBack:_saveValidTagBtn];
    _matchView.hidden = YES;
    _noMatchView.hidden = YES;
    _saveValidTagBtn.hidden = YES;
    
// TPM - This logic assumes that once you've read a tag with one type of reader, you won't switch
// to another.  If you change readers, restart the app.  The first reader to scan a tag sets the
// reader flags for that session.  Until then, all protocols are attempted until a tag is found.
    
    // If no connection open, open it now and start scanning for RFID tags
    // Before we know what reader, we try all, so test the negative

    // uGrokit Reader
    if (!_zebraReaderConnected) {
        [[Ugi singleton].activeInventory stopInventory];
        [[Ugi singleton] closeConnection];
        [[Ugi singleton] openConnection];  // Once the reader is connected, this triggers the tag reads
        _rfidLbl.text = @"RFID: (connecting to reader)";
    }
    
    // Zebra Reader
    if (!_ugiReaderConnected) {
        [_rfidSdkApi srfidStopRapidRead:_zebraReaderID aStatusMessage:nil];
        [_rfidSdkApi srfidTerminateCommunicationSession:_zebraReaderID];
        _zebraReaderID = -1;
        _rfidLbl.text = @"RFID: (connecting to reader)";
        [self zebraRapidRead];
    }
}

/*!
 * @discussion Press the save button
 * @param sender An id for the sender control (not used)
 */
- (IBAction)saveValidTag:(id)sender {
    
    // Were we invoked from another caller?
    if (MyAppDelegate.autoSaveAndExit) {
        if ([self autoSaveValidTag]) {
            // We've saved new valid tag, return to caller app
            [MyAppDelegate returnToCaller];
            return;
        }
    }
    
    NSURL *tagReadsGroupURL = [[NSFileManager defaultManager]
                               containerURLForSecurityApplicationGroupIdentifier:
                               @"group.com.timmilne.tagreads"];
    NSString *validTagFile = [[NSString alloc] initWithFormat:@"validTag.dat"];
    NSURL *validTagFileURL = [[NSURL alloc] initFileURLWithPath:validTagFile
                                                    isDirectory:false
                                                  relativeToURL:tagReadsGroupURL];
    NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self];
    NSError *fileCoordinatorError = nil;
    
    [fileCoordinator coordinateWritingItemAtURL:validTagFileURL
                                        options:NSFileCoordinatorWritingForReplacing
                                          error:&fileCoordinatorError
                                     byAccessor:^(NSURL *newURL) {
                                         // Save to a file
                                         if ([NSKeyedArchiver archiveRootObject:checkData
                                                                         toFile:[newURL path]]) {
                                             [self alertDialog:@"saveValidTag"
                                                   withMessage:[NSString stringWithFormat:@"File Saved: %@",
                                                                [newURL path]]];
                                         }
                                         else {
                                             // Error!
                                             [self alertDialog:@"saveValidTag"
                                                   withMessage:[NSString stringWithFormat:@"File Save Error"]];
                                         }
                                     }];

}

/*!
 * @discussion Auto Save - just like above, but no dialog prompt for success or error
 */
- (BOOL)autoSaveValidTag {
    NSURL *tagReadsGroupURL = [[NSFileManager defaultManager]
                               containerURLForSecurityApplicationGroupIdentifier:
                               @"group.com.timmilne.tagreads"];
    NSString *validTagFile = [[NSString alloc] initWithFormat:@"validTag.dat"];
    NSURL *validTagFileURL = [[NSURL alloc] initFileURLWithPath:validTagFile
                                                    isDirectory:false
                                                  relativeToURL:tagReadsGroupURL];
    NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self];
    NSError *fileCoordinatorError = nil;
    
    __block BOOL success = FALSE;
    
    [fileCoordinator coordinateWritingItemAtURL:validTagFileURL
                                        options:NSFileCoordinatorWritingForReplacing
                                          error:&fileCoordinatorError
                                     byAccessor:^(NSURL *newURL) {
                                         // Save to a file
                                         if ([NSKeyedArchiver archiveRootObject:checkData
                                                                         toFile:[newURL path]]) {
                                             NSLog(@"autoSaveValidTag File Saved: %@",[newURL path]);
                                             success = TRUE;
                                         }
                                         else {
                                             // Error!
                                             NSLog(@"autoSaveValidTag: File Save Error");
                                         }
                                     }];
    return success;
}

/*!
 * @discussion Load Valid Tag from a previous save
 */
- (BOOL)loadValidTag {
    NSURL *tagReadsGroupURL = [[NSFileManager defaultManager]
                               containerURLForSecurityApplicationGroupIdentifier:
                               @"group.com.timmilne.tagreads"];
    NSString *validTagFile = [[NSString alloc] initWithFormat:@"validTag.dat"];
    NSURL *validTagFileURL = [[NSURL alloc] initFileURLWithPath:validTagFile
                                                    isDirectory:false
                                                  relativeToURL:tagReadsGroupURL];
    if ([[NSFileManager defaultManager] isReadableFileAtPath:[validTagFileURL path]]) {
        // Ok, we have something to do
        NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self];
        NSError *fileCoordinatorError = nil;
        __block BOOL loaded = FALSE;
        
        [fileCoordinator coordinateReadingItemAtURL:validTagFileURL
                                            options:0
                                              error:&fileCoordinatorError
                                         byAccessor:^(NSURL *newURL) {
                                             // Load from file
                                             NSData *validTagData = [NSData dataWithContentsOfURL:newURL];
                                             
                                             if (validTagData != nil) {
                                                 // Because this is a singleton, I don't
                                                 // need to catch the return value...
                                                 [NSKeyedUnarchiver unarchiveObjectWithData:validTagData];
                                                 loaded = TRUE;
                                             }
                                         }];
        if (loaded) {
            return TRUE;
        }
        else {
            // Error!
            [self alertDialog:@"loadValidTag" withMessage:@"File Load Error: Error loading file."];
            return FALSE;
        }
    }
    else {
        // Error!
        [self alertDialog:@"loadValidTag" withMessage:@"File Load Error: No validTag file available."];
        return FALSE;
    }
}

/*!
 * @discussion NSFilePresenter Notification if the shared file changed
 */
- (void)presentedItemDidChange {
    // Reload the validTag data, it changed...
    [self loadValidTag];
}

- (void)alertDialog:(NSString *)title withMessage:(NSString *)message {
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:title
                          message:message
                          delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [alert show];
    });
    NSLog (@"%@", message);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*!
 * @discussion If both available, check the possible barcode encodings based on the RFID tag
 */
- (void)checkEncodings {
    // Are we ready to check?
    if (!_barcodeFound || !_rfidFound) return;
    
    if (!_barcodeProcessed) {
        NSString *barcode;
        barcode = checkData.barcode;
        
        // Set the defaults
        [checkData.dpt setString:@""];
        [checkData.cls setString:@""];
        [checkData.itm setString:@""];
        
        // Quick length checks, chop to 12 for now (remove leading zeros)
        if (barcode.length == 13) barcode = [barcode substringFromIndex:1];
        if (barcode.length == 14) barcode = [barcode substringFromIndex:2];
        
        // Vendor provided owned brand DPCI encoded in an SGTIN
        // NOTE: this only works if the RFID tag has already been read
        if ((barcode.length == 12) &&
            ([checkData.rfidBin length] > 0) &&
            ([[checkData.rfidBin substringToIndex:8] isEqualToString:SGTIN_Bin_Prefix]) &&
            ([[barcode substringToIndex:2] isEqualToString:@"49"])) {
            
            [_encode withGTIN:barcode ser:@"0" partBin:[checkData.rfidBin substringWithRange:NSMakeRange(11,3)]];
            
            [checkData.encodedBarcode setString:[_encode sgtin_hex]];
            [checkData.encodedBarcodeBin setString:[_convert Hex2Bin:checkData.encodedBarcode]];
            
            [checkData.dpt setString:[barcode substringWithRange:NSMakeRange(2,3)]];
            [checkData.cls setString:[barcode substringWithRange:NSMakeRange(5,2)]];
            [checkData.itm setString:[barcode substringWithRange:NSMakeRange(7,4)]];
            
            // Log the read barcode
            NSLog(@"\nBar code read: %@\n", barcode);
        }
        
        // Owned brand DPCI properly encoded in a GID
        // NOTE: this is the only one that works without the RFID tag, but we'll check it for completeness
        else if ((barcode.length == 12) &&
                 ([checkData.rfidBin length] > 0) &&
                 ([[checkData.rfidBin substringToIndex:8] isEqualToString:GID_Bin_Prefix]) &&
                 ([[barcode substringToIndex:2] isEqualToString:@"49"])) {
            
            NSString *dpt = [barcode substringWithRange:NSMakeRange(2,3)];
            NSString *cls = [barcode substringWithRange:NSMakeRange(5,2)];
            NSString *itm = [barcode substringWithRange:NSMakeRange(7,4)];
            
            [_encode withDpt:dpt cls:cls itm:itm ser:@"0"];
            
            [checkData.encodedBarcode setString:[_encode gid_hex]];
            [checkData.encodedBarcodeBin setString:[_convert Hex2Bin:checkData.encodedBarcode]];
            
            [checkData.dpt setString:dpt];
            [checkData.cls setString:cls];
            [checkData.itm setString:itm];
            
            // Log the read barcode
            NSLog(@"\nBar code read: %@\n", barcode);
        }
        
        // National brand replacement tag encoded in GID with commissioning authority
        // Make sure the serial number is 10 digits long and check the first two digits of the serial number
        // for 01, 02, 03, 04 (remembering that the decoder drops leading zeroes, so it's a 9 digit number that
        // would start with 1, 2, 3, or 4.  These are reserved for Target's commisioning authority).
        // NOTE: this only works if the RFID tag has already been read
        else if ((barcode.length == 12) &&
                 ([checkData.rfidBin length] > 0) &&
                 ([[checkData.rfidBin substringToIndex:8] isEqualToString:GID_Bin_Prefix]) &&
                 ([checkData.ser length] == 9) &&
                 (([[checkData.ser substringToIndex:1] isEqualToString:@"1"]) ||
                  ([[checkData.ser substringToIndex:1] isEqualToString:@"2"]) ||
                  ([[checkData.ser substringToIndex:1] isEqualToString:@"3"]) ||
                  ([[checkData.ser substringToIndex:1] isEqualToString:@"4"]))) {
            
            [_encode gidWithGTIN:barcode ser:@"0"];
            
            [checkData.encodedBarcode setString:[_encode gid_hex]];
            [checkData.encodedBarcodeBin setString:[_convert Hex2Bin:checkData.encodedBarcode]];
            
            // Log the read barcode
            NSLog(@"\nBar code read: %@\n", barcode);
        }
        
        // National brand GTIN encoded in SGTIN
        // NOTE: this only works if the RFID tag has already been read
        else if ((barcode.length == 12) &&
                 ([checkData.rfidBin length] > 0) &&
                 ([[checkData.rfidBin substringToIndex:8] isEqualToString:SGTIN_Bin_Prefix])) {
            
            [_encode withGTIN:barcode ser:@"0" partBin:[checkData.rfidBin substringWithRange:NSMakeRange(11,3)]];
            
            [checkData.encodedBarcode setString:[_encode sgtin_hex]];
            [checkData.encodedBarcodeBin setString:[_convert Hex2Bin:checkData.encodedBarcode]];
            
            // Log the read barcode
            NSLog(@"\nBar code read: %@\n", barcode);
        }
        
        //Unsupported barcode
        else {
            [checkData.barcode setString:@"unsupported barcode"];
            [checkData.encodedBarcode setString:@"unsupported barcode"];
            [checkData.encodedBarcodeBin setString:@"unsupported barcode"];
            
            // Log the unsupported barcode
            NSLog(@"\nUnsupported barcode: %@\n", barcode);
        }
        
        // Landscape labels
        _dptLbl.text = [NSString stringWithFormat:@"Department: %@", checkData.dpt];
        _clsLbl.text = [NSString stringWithFormat:@"Class: %@", checkData.cls];
        _itmLbl.text = [NSString stringWithFormat:@"Item: %@", checkData.itm];
        _encodedBarcodeLbl.text = checkData.encodedBarcode;
        _barcodeProcessed = TRUE;
    }
    
    // Check for match
    [self checkForMatch];
}

/*!
 * @discussion Check the barcode and RFID tag for a match - Only proceed if both scanned and available.
 */
- (void)checkForMatch {
    // Are we ready to check?
    if (!_barcodeFound || !_rfidFound) return;
    
    // Compare the binary formats: SGTIN = 58, GID = 60
    int length = ([[checkData.rfidBin substringToIndex:8] isEqualToString:SGTIN_Bin_Prefix])?58:60;
    if ([checkData.rfidBin length] > length && [checkData.encodedBarcodeBin length] > length &&
        [[checkData.rfidBin substringToIndex:(length-1)] isEqualToString:[checkData.encodedBarcodeBin substringToIndex:(length-1)]]) {
        // Match: hide the no match and show the match
        [self.view bringSubviewToFront:_matchView];
        [self.view sendSubviewToBack:_noMatchView];
        [self.view bringSubviewToFront:_saveValidTagBtn];
        _matchView.hidden = NO;
        _noMatchView.hidden = YES;
        _saveValidTagBtn.hidden = NO;
        _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
        _rfidLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
        [self.view setBackgroundColor:UIColorFromRGB(0xA4CD39)];
        if (MyAppDelegate.autoSaveAndExit) {
            if ([self autoSaveValidTag]) {
                // We've saved a valid tag, return to caller app
                [MyAppDelegate returnToCaller];
            }
        }
    }
    else {
        // No match: hide the match and show the no match
        [self.view bringSubviewToFront:_noMatchView];
        [self.view sendSubviewToBack:_matchView];
        [self.view sendSubviewToBack:_saveValidTagBtn];
        _matchView.hidden = YES;
        _noMatchView.hidden = NO;
        _saveValidTagBtn.hidden = YES;
        _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
        _rfidLbl.backgroundColor = UIColorFromRGB(0xCC0000);
        [self.view setBackgroundColor:UIColorFromRGB(0xCC0000)];
    }
}

- (void)returnToCaller {
    NSString *customURL = @"FindaTag://";
    
    if ([[UIApplication sharedApplication]
         canOpenURL:[NSURL URLWithString:customURL]])
    {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:customURL]];
    }
    else
    {
        [self alertDialog:@"URL Error"
              withMessage:[NSString stringWithFormat: @"No custom URL defined for %@", customURL]];
    }
}

// Zebra RFID Reader
#pragma mark - Zebra Reader Support

/*!
 * @discussion Initialize the Zebra reader and start a rapid read.
 */
- (void)zebraInitializeRfidSdkWithAppSettings
{
    _rfidSdkApi = [srfidSdkFactory createRfidSdkApiInstance];
    [_rfidSdkApi srfidSetDelegate:self];
    
    int notifications_mask = SRFID_EVENT_READER_APPEARANCE |
    SRFID_EVENT_READER_DISAPPEARANCE | // Not really needed
    SRFID_EVENT_SESSION_ESTABLISHMENT |
    SRFID_EVENT_SESSION_TERMINATION; // Not really needed
    [_rfidSdkApi srfidSetOperationalMode:SRFID_OPMODE_MFI];
    [_rfidSdkApi srfidSubsribeForEvents:notifications_mask];
    [_rfidSdkApi srfidSubsribeForEvents:(SRFID_EVENT_MASK_READ | SRFID_EVENT_MASK_STATUS)]; // Event mask not needed
    [_rfidSdkApi srfidSubsribeForEvents:(SRFID_EVENT_MASK_PROXIMITY)]; // Not really needed
    [_rfidSdkApi srfidSubsribeForEvents:(SRFID_EVENT_MASK_TRIGGER)]; // Not really needed
    [_rfidSdkApi srfidSubsribeForEvents:(SRFID_EVENT_MASK_BATTERY)];
    [_rfidSdkApi srfidEnableAvailableReadersDetection:YES];
    [_rfidSdkApi srfidEnableAutomaticSessionReestablishment:YES];
    
    _startTriggerConfig = [[srfidStartTriggerConfig alloc] init];
    _stopTriggerConfig  = [[srfidStopTriggerConfig alloc] init];
    _reportConfig       = [[srfidReportConfig alloc] init];
    _accessConfig       = [[srfidAccessConfig alloc] init];
    
    // Configure start and stop triggers parameters to start and stop actual
    // operation immediately on a corresponding response
    [_startTriggerConfig setStartOnHandheldTrigger:NO];
    [_startTriggerConfig setStartDelay:0];
    [_startTriggerConfig setRepeatMonitoring:NO];
    [_stopTriggerConfig setStopOnHandheldTrigger:NO];
    [_stopTriggerConfig setStopOnTimeout:NO];
    [_stopTriggerConfig setStopOnTagCount:YES];
    [_stopTriggerConfig setStopOnInventoryCount:YES];
    [_stopTriggerConfig setStopTagCount:1];
    [_stopTriggerConfig setStopOnAccessCount:NO];
    
    // Configure report parameters to report RSSI, Channel Index, Phase and PC fields
    [_reportConfig setIncPC:YES];
    [_reportConfig setIncPhase:YES];
    [_reportConfig setIncChannelIndex:YES];
    [_reportConfig setIncRSSI:YES];
    [_reportConfig setIncTagSeenCount:NO];
    [_reportConfig setIncFirstSeenTime:NO];
    [_reportConfig setIncLastSeenTime:NO];
    
    // Configure access parameters to perform the operation with 12.0 dbm antenna
    // power level without application of pre-filters for close proximity
    [_accessConfig setPower:120];
    [_accessConfig setDoSelect:NO];
    
    // See if a reader is already connected and try and read a tag
    [self zebraRapidRead];
}

/*!
 * @discussion Kick off a Zebra Rapid Read.
 */
- (void)zebraRapidRead
{
    if (_zebraReaderID < 0) {
        // Get an available reader (must connect with bluetooth settings outside of app)
        NSMutableArray *readers = [[NSMutableArray alloc] init];
        [_rfidSdkApi srfidGetAvailableReadersList:&readers];
        
        for (srfidReaderInfo *reader in readers)
        {
            SRFID_RESULT result = [_rfidSdkApi srfidEstablishCommunicationSession:[reader getReaderID]];
            if (result == SRFID_RESULT_SUCCESS) {
                break;
            }
        }
    }
    else {
        [_rfidSdkApi srfidRequestBatteryStatus:_zebraReaderID];
        
        NSString *error_response = nil;
        
        do {
            // Set start trigger parameters
            SRFID_RESULT result = [_rfidSdkApi srfidSetStartTriggerConfiguration:_zebraReaderID
                                                              aStartTriggeConfig:_startTriggerConfig
                                                                  aStatusMessage:&error_response];
            if (SRFID_RESULT_SUCCESS == result) {
                // Start trigger configuration applied
                NSLog(@"Zebra Start trigger configuration has been set\n");
            } else {
                NSLog(@"Zebra Failed to set start trigger parameters\n");
                break;
            }
            
            // Set stop trigger parameters
            result = [_rfidSdkApi srfidSetStopTriggerConfiguration:_zebraReaderID
                                                 aStopTriggeConfig:_stopTriggerConfig
                                                    aStatusMessage:&error_response];
            if (SRFID_RESULT_SUCCESS == result) {
                // Stop trigger configuration applied
                NSLog(@"Zebra Stop trigger configuration has been set\n");
            } else {
                NSLog(@"Zebra Failed to set stop trigger parameters\n");
                break;
            }
            
            // Start and stop triggers have been configured
            error_response = nil;
            
            // Request performing of rapid read operation
            result = [_rfidSdkApi srfidStartRapidRead:_zebraReaderID
                                        aReportConfig:_reportConfig
                                        aAccessConfig:_accessConfig
                                       aStatusMessage:&error_response];
            if (SRFID_RESULT_SUCCESS == result) {
                NSLog(@"Zebra Request succeeded\n");
                
                _rfidLbl.text = @"RFID: (scanning for tags)";
                _rfidLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
                
                // Stop an operation after 1 minute
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 *
                                                                          NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [_rfidSdkApi srfidStopRapidRead:_zebraReaderID aStatusMessage:nil];
                });
            }
            else if (SRFID_RESULT_RESPONSE_ERROR == result) {
                NSLog(@"Zebra Error response from RFID reader: %@\n", error_response);
            }
            else {
                NSLog(@"Zebra Request failed\n");
            }
        } while (0); // Only do this once, but break on any errors (Objective-C GO TO :)
    }
}

// Barcode scanner
#pragma mark - Barcode Scanner Delegates

/*!
 * @discussion Check for a valid scanned barcode, only proceed if a valid barcode found.
 */
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    CGRect highlightViewRect = CGRectZero;
    AVMetadataMachineReadableCodeObject *barCodeObject;
    NSString *detectionString = nil;
    NSString *type;
    
// TPM don't check all barcode types, but these are the ones iOS supports.
    NSArray *barCodeTypes = @[AVMetadataObjectTypeUPCECode,
//                              AVMetadataObjectTypeCode39Code,
//                              AVMetadataObjectTypeCode39Mod43Code,
                              AVMetadataObjectTypeEAN13Code,
//                              AVMetadataObjectTypeEAN8Code,
//                              AVMetadataObjectTypeCode93Code,
//                              AVMetadataObjectTypeCode128Code,
//                              AVMetadataObjectTypePDF417Code,
//                              AVMetadataObjectTypeQRCode,
//                              AVMetadataObjectTypeAztecCode,
//                              AVMetadataObjectTypeInterleaved2of5Code,
//                              AVMetadataObjectTypeITF14Code,
//                              AVMetadataObjectTypeDataMatrixCode
                              ];
    
    for (AVMetadataObject *metadata in metadataObjects) {
        for (type in barCodeTypes) {
            if ([metadata.type isEqualToString:type])
            {
                barCodeObject = (AVMetadataMachineReadableCodeObject *)[_prevLayer transformedMetadataObjectForMetadataObject:(AVMetadataMachineReadableCodeObject *)metadata];
                highlightViewRect = barCodeObject.bounds;
                detectionString = [(AVMetadataMachineReadableCodeObject *)metadata stringValue];
                break;
            }
        }
        
        // Update before returning
        _highlightView.frame = highlightViewRect;
        
        if (detectionString != nil) {
            // Don't keep processing the same barcode
            if ([_lastDetectionString isEqualToString:detectionString]) return;
            [_lastDetectionString setString:detectionString];
            
            // Save the (new) barcode
            [checkData.barcode setString:detectionString];
            _barcodeProcessed = FALSE;
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@", detectionString];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
            _barcodeFound = TRUE;
        }
    }

    // This clears the scan rectangle if empty
    _highlightView.frame = highlightViewRect;

    // Check encodings
    [self checkEncodings];
}

// uGrokit RFID Reader
#pragma mark - uGrokit Delegates

/*!
 * @discussion New tag found with uGrokit reader.
 * Display the tag, stop the reader, disable the other readers, and check for a match.
 * @param tag The RFID tag
 * @param detailedPerReadData The detailed data about the RFID tag
 */
- (void) inventoryTagFound:(UgiTag *)tag
   withDetailedPerReadData:(NSArray *)detailedPerReadData {
    // tag was found for the first time
    
    // Stop the RFID reader
    [[Ugi singleton].activeInventory stopInventory];
    
    // Get the RFID tag
    [checkData.rfid setString:[tag.epc toString]];
    [checkData.rfidBin setString:[_convert Hex2Bin:checkData.rfid]];
    _rfidLbl.text = [NSString stringWithFormat:@"RFID: %@", checkData.rfid];
    _rfidLbl.backgroundColor = UIColorFromRGB(0xA4CD39);

    // Get the serial number from the tag read (assuming GID, and only used for national brand replacement tags)
    [checkData.ser setString:[_convert Bin2Dec:[checkData.rfidBin substringFromIndex:60]]];
    
    // Landscape label
    _serLbl.text = [NSString stringWithFormat:@"Serial Num: %@", checkData.ser];
    
    // Close the connection
    [[Ugi singleton] closeConnection];
    
    // After the first read, we know which reader
    _rfidFound = TRUE;
    if (!_ugiReaderConnected) {
        [_rfidSdkApi srfidStopRapidRead:_zebraReaderID aStatusMessage:nil];
        [_rfidSdkApi srfidTerminateCommunicationSession:_zebraReaderID];
        _zebraReaderID = -1;
    }
    _ugiReaderConnected = TRUE;
    _zebraReaderConnected = FALSE;
  
    // Check encodings
    [self checkEncodings];
    
    // Log the read tag
    NSLog(@"\nRFID tag read: %@\n", checkData.rfid);
}

/*!
 * @discussion State changed with uGrokit reader - Adjust to the new state, ignore if Arete reader being used.
 * Listen for one of the following:
 *    UGI_CONNECTION_STATE_NOT_CONNECTED -          Nothing connected to audio port
 *    UGI_CONNECTION_STATE_CONNECTING -             Something connected to audio port, trying to connect
 *    UGI_CONNECTION_STATE_INCOMPATIBLE_READER -    Connected to an reader with incompatible firmware
 *    UGI_CONNECTION_STATE_CONNECTED -              Connected to reader
 * @param notification The notification info
 */
- (void)connectionStateChanged:(NSNotification *) notification {
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
        [[Ugi singleton] startInventory:self withConfiguration:_ugiConfig];
        return;
    }
    if (connectionState == UGI_CONNECTION_STATE_CONNECTING) {
        _rfidLbl.text = @"RFID: (connecting to reader)";
        return;
    }
    if (connectionState == UGI_CONNECTION_STATE_INCOMPATIBLE_READER) {
        // With no reader, just ignore the RFID reads
        [checkData.rfid setString:@"RFID: no reader found"];
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

// Zebra RFID Reader
#pragma mark - Zebra Delegates

/*!
 * @discussion Zebra reader appeared - Adjust to the new state.
 * @param availableReader Reader info about the newly appeared reader
 */
- (void)srfidEventReaderAppeared:(srfidReaderInfo*)availableReader
{
    NSLog(@"Zebra Reader Appeared - Name: %@\n", [availableReader getReaderName]);

    if ([_rfidSdkApi srfidEstablishCommunicationSession:[availableReader getReaderID]] != SRFID_RESULT_SUCCESS) {
        NSLog(@"Zebra Reader: Could not connect\n");
    }
}

/*!
 * @discussion Zebra reader communication established - Start reading
 * @param activeReader Reader info for the active reader
 */
- (void)srfidEventCommunicationSessionEstablished:(srfidReaderInfo*)activeReader
{
    NSLog(@"Zebra Communication Established - Name: %@\n", [activeReader getReaderName]);
    
    // Set the reader
    _zebraReaderID = [activeReader getReaderID];
    
    // Establish ASCII connection
    if ([_rfidSdkApi srfidEstablishAsciiConnection:_zebraReaderID aPassword:nil] == SRFID_RESULT_SUCCESS)
    {
        // Set the volume
        NSString *statusMessage = nil;
        [_rfidSdkApi srfidSetBeeperConfig:_zebraReaderID
                            aBeeperConfig:SRFID_BEEPERCONFIG_LOW
                           aStatusMessage:&statusMessage];
        
        // Success, now read tags
        [self zebraRapidRead];
    }
    else
    {
        // Error, alert
        [self alertDialog:@"Zebra Error"
              withMessage:@"Failed to establish connection with Zebra RFID reader"];
        
        // Terminate sesssion
        [_rfidSdkApi srfidTerminateCommunicationSession:_zebraReaderID];
        _zebraReaderID = -1;
        _rfidLbl.text = @"RFID: Zebra connection failed";
        _rfidLbl.backgroundColor = UIColorFromRGB(0xCC0000);
    }
}

/*!
 * @discussion New tag found with Zebra reader
 * Display the tag, stop the reader, disable the other readers, and check for a match.
 * @param readerID The ID of the reader
 * @param aTagData The data in the RFID tag
 */
- (void)srfidEventReadNotify:(int)readerID aTagData:(srfidTagData*)tagData
{
    dispatch_async(dispatch_get_main_queue(),
                   ^{
                       // tag was found for the first time
    
                       // Stop the RFID reader
                       [_rfidSdkApi srfidStopRapidRead:readerID aStatusMessage:nil];
                       
                       // Close the connection
                       [_rfidSdkApi srfidTerminateCommunicationSession:readerID];
                       if (readerID == _zebraReaderID) _zebraReaderID = -1;
                       
                       // Get the RFID tag
                       [checkData.rfid setString:[tagData getTagId]];
                       [checkData.rfidBin setString:[_convert Hex2Bin:checkData.rfid]];
                       _rfidLbl.text = [NSString stringWithFormat:@"RFID: %@", checkData.rfid];
                       _rfidLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
    
                       // Get the serial number from the tag read (assuming GID, and only used for national brand replacement tags)
                       [checkData.ser setString:[_convert Bin2Dec:[checkData.rfidBin substringFromIndex:60]]];
    
                       // Landscape label
                       _serLbl.text = [NSString stringWithFormat:@"Serial Num: %@", checkData.ser];
    
                       // After the first read, we know which reader
                       _rfidFound = TRUE;
                       if (!_zebraReaderConnected) {
                           [[Ugi singleton].activeInventory stopInventory];
                           [[Ugi singleton] closeConnection];
                       }
                       _ugiReaderConnected = FALSE;
                       _zebraReaderConnected = TRUE;
    
                       // Check encodings
                       [self checkEncodings];
                       
                       // Log the read tag
                       NSLog(@"\nRFID tag read: %@\n", checkData.rfid);
                   });
}

/*!
 * @discussion Set the battery life of the Zebra reader.
 * @warning This delegate is called at random intervals (Stochastic baby!), or can be prompted by the SDK
 */
- (void)srfidEventBatteryNotity:(int)readerID aBatteryEvent:(srfidBatteryEvent*)batteryEvent
{
    // Thread is unknown
    NSLog(@"\nbatteryEvent: level = [%d] charging = [%d] cause = (%@)\n", [batteryEvent getPowerLevel], [batteryEvent getIsCharging], [batteryEvent getEventCause]);

    int battery = [batteryEvent getPowerLevel];
    
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
 None of these are really needed
 */
- (void)srfidEventReaderDisappeared:(int)readerID
{
    NSLog(@"Zebra Reader Disappeared - ID: %d\n", readerID);
}
- (void)srfidEventCommunicationSessionTerminated:(int)readerID
{
    NSLog(@"Zebra Reader Session Terminated - ID: %d\n", readerID);
}
- (void)srfidEventStatusNotify:(int)readerID aEvent:(SRFID_EVENT_STATUS)event aNotification:(id)notificationData
{
    NSLog(@"Zebra Reader - Event status notify: %d\n", event);
}
- (void)srfidEventProximityNotify:(int)readerID aProximityPercent:(int)proximityPercent
{
    NSLog(@"Zebra Reader - Event proximity nofity percent: %d\n", proximityPercent);
}
- (void)srfidEventTriggerNotify:(int)readerID aTriggerEvent:(SRFID_TRIGGEREVENT)triggerEvent
{
    NSLog(@"Zebra Reader - Event trigger notify: %@\n", ((triggerEvent == SRFID_TRIGGEREVENT_PRESSED)?@"Pressed":@"Released"));
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
