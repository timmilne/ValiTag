//
//  DataViewController.m
//  ValiTag
//
//  Created by Tim.Milne on 5/6/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import "DataViewController.h"
#import "DataClass.h"                   // Singleton data class
#import "EPCEncoder.h"                  // To encode the scanned barcode for comparison

@interface DataViewController ()
@property (weak, nonatomic) IBOutlet UILabel *scannedBarcodeLbl;
@property (weak, nonatomic) IBOutlet UILabel *encodedBarcodeLbl;
@property (weak, nonatomic) IBOutlet UILabel *scannedRFIDLbl;
@property (weak, nonatomic) IBOutlet UILabel *departmentLbl;
@property (weak, nonatomic) IBOutlet UILabel *classLbl;
@property (weak, nonatomic) IBOutlet UILabel *itemLbl;
@property (weak, nonatomic) IBOutlet UILabel *serialLbl;

@end

// The singleton data class
extern DataClass *data;

@implementation DataViewController

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:0.65]

- (void)viewDidLoad {
    [super viewDidLoad];

    // Set the status bar to white (iOS bug)
    // Also had to add the statusBarStyle entry to info.plist
    self.navigationController.navigationBar.barStyle = UIStatusBarStyleLightContent;
    
    // We better not have gotten here without doing this, but just in case...
    data = [DataClass singleton:FALSE];
    
    // Do any additional setup after loading the view.
    _scannedBarcodeLbl.text = data.barcode;
    _encodedBarcodeLbl.text = data.encodedBarcode;
    _scannedRFIDLbl.text = data.rfid;
    _departmentLbl.text = [NSString stringWithFormat:@"Department: %@", data.dpt];
    _classLbl.text = [NSString stringWithFormat:@"Class: %@", data.cls];
    _itemLbl.text = [NSString stringWithFormat:@"Item: %@", data.itm];
    _serialLbl.text = [NSString stringWithFormat:@"Serial Number: %@", data.ser];
    
    // Compare the binary formats
    if ([data.rfidBin length] > 60 && [data.encodedBarcodeBin length] > 60 &&
        [[data.rfidBin substringToIndex:59] isEqualToString:[data.encodedBarcodeBin substringToIndex:59]]) {
        // Match: hide the no match and show the match
        [self.view setBackgroundColor:UIColorFromRGB(0xA4CD39)];
    }
    else {
        // No match: hide the match and show the no match
        [self.view setBackgroundColor:UIColorFromRGB(0xCC0000)];
    }
    
    // Compare the binary formats: SGTIN = 58, GID = 60
    int length = ([[data.rfidBin substringToIndex:8] isEqualToString:SGTIN_Bin_Prefix])?58:60;
    if ([data.rfidBin length] > length && [data.encodedBarcodeBin length] > length &&
        [[data.rfidBin substringToIndex:(length-1)] isEqualToString:[data.encodedBarcodeBin substringToIndex:(length-1)]]) {
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
