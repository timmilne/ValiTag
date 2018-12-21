//
//  DataViewController.m
//  ValiTag
//
//  Created by Tim.Milne on 5/6/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import "DataViewController.h"
#import "CheckDataObject.h"         // Singleton check data data object
#import <EPCEncoder/EPCEncoder.h>   // To encode the scanned barcode for comparison

@interface DataViewController ()
@property (weak, nonatomic) IBOutlet UILabel *scannedBarcodeLbl;
@property (weak, nonatomic) IBOutlet UILabel *encodedBarcodeLbl;
@property (weak, nonatomic) IBOutlet UILabel *scannedRFIDLbl;
@property (weak, nonatomic) IBOutlet UILabel *departmentLbl;
@property (weak, nonatomic) IBOutlet UILabel *classLbl;
@property (weak, nonatomic) IBOutlet UILabel *itemLbl;
@property (weak, nonatomic) IBOutlet UILabel *serialLbl;
@property (weak, nonatomic) IBOutlet UILabel *versionLbl;

@end

// The singleton check data object
extern CheckDataObject *checkData;

@implementation DataViewController

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:0.65]

- (void)viewDidLoad {
    [super viewDidLoad];

    // Set the status bar to white (iOS bug)
    // Also had to add the statusBarStyle entry to info.plist
    self.navigationController.navigationBar.barStyle = UIStatusBarStyleLightContent;
    
    // We better not have gotten here without doing this, but just in case...
    checkData = [CheckDataObject singleton:FALSE];
    
    // Do any additional setup after loading the view.
    _scannedBarcodeLbl.text = checkData.barcode;
    _encodedBarcodeLbl.text = checkData.encodedBarcode;
    _scannedRFIDLbl.text = checkData.rfid;
    _departmentLbl.text = [NSString stringWithFormat:@"Department: %@", checkData.dpt];
    _classLbl.text = [NSString stringWithFormat:@"Class: %@", checkData.cls];
    _itemLbl.text = [NSString stringWithFormat:@"Item: %@", checkData.itm];
    _serialLbl.text = [NSString stringWithFormat:@"Serial Number: %@", checkData.ser];
    _versionLbl.text = [NSString stringWithFormat:@"ValiTag Version: %@",
                        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    
    // Compare the binary formats
    if ([checkData.rfidBin length] > 60 && [checkData.encodedBarcodeBin length] > 60 &&
        [[checkData.rfidBin substringToIndex:59] isEqualToString:[checkData.encodedBarcodeBin substringToIndex:59]]) {
        // Match: hide the no match and show the match
        [self.view setBackgroundColor:UIColorFromRGB(0xA4CD39)];
    }
    else {
        // No match: hide the match and show the no match
        [self.view setBackgroundColor:UIColorFromRGB(0xCC0000)];
    }
    
    // Compare the binary formats: SGTIN = 58, GID = 60
    int length = ([checkData.rfidBin length] > 0 && [[checkData.rfidBin substringToIndex:8] isEqualToString:SGTIN_Bin_Prefix])?58:60;
    if ([checkData.rfidBin length] > length && [checkData.encodedBarcodeBin length] > length &&
        [[checkData.rfidBin substringToIndex:(length-1)] isEqualToString:[checkData.encodedBarcodeBin substringToIndex:(length-1)]]) {
        // Match: hide the no match and show the match
        [self.view setBackgroundColor:UIColorFromRGB(0xA4CD39)];
    }
    else {
        // No match: hide the match and show the no match
        [self.view setBackgroundColor:UIColorFromRGB(0xCC0000)];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
