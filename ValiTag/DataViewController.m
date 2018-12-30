//
//  DataViewController.m
//  ValiTag
//
//  Created by Tim.Milne on 5/6/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import "DataViewController.h"
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

@implementation DataViewController

@synthesize validTag;

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:0.65]

- (void)viewDidLoad {
    [super viewDidLoad];

    // Set the status bar to white (iOS bug)
    // Also had to add the statusBarStyle entry to info.plist
    self.navigationController.navigationBar.barStyle = UIStatusBarStyleLightContent;
    
    // Do any additional setup after loading the view.
    _scannedBarcodeLbl.text = validTag.barcode;
    _encodedBarcodeLbl.text = validTag.encodedBarcode;
    _scannedRFIDLbl.text = validTag.rfid;
    _departmentLbl.text = [NSString stringWithFormat:@"Department: %@", validTag.dpt];
    _classLbl.text = [NSString stringWithFormat:@"Class: %@", validTag.cls];
    _itemLbl.text = [NSString stringWithFormat:@"Item: %@", validTag.itm];
    _serialLbl.text = [NSString stringWithFormat:@"Serial Number: %@", validTag.ser];
    _versionLbl.text = [NSString stringWithFormat:@"ValiTag Version: %@",
                        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    
    // Compare the binary formats
    if ([validTag.rfidBin length] > 60 && [validTag.encodedBarcodeBin length] > 60 &&
        [[validTag.rfidBin substringToIndex:59] isEqualToString:[validTag.encodedBarcodeBin substringToIndex:59]]) {
        // Match: hide the no match and show the match
        [self.view setBackgroundColor:UIColorFromRGB(0xA4CD39)];
    }
    else {
        // No match: hide the match and show the no match
        [self.view setBackgroundColor:UIColorFromRGB(0xCC0000)];
    }
    
    // Compare the binary formats: SGTIN = 58, GID = 60
    int length = ([validTag.rfidBin length] > 0 && [[validTag.rfidBin substringToIndex:8] isEqualToString:SGTIN_Bin_Prefix])?58:60;
    if ([validTag.rfidBin length] > length && [validTag.encodedBarcodeBin length] > length &&
        [[validTag.rfidBin substringToIndex:(length-1)] isEqualToString:[validTag.encodedBarcodeBin substringToIndex:(length-1)]]) {
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
