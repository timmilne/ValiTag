//
//  DataViewController.m
//  ValiTag
//
//  Created by Tim.Milne on 5/6/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import "DataViewController.h"
#import <RFIDEncoder/EPCEncoder.h>   // To encode the scanned barcode for comparison
#import <RFIDEncoder/TCINEncoder.h>  // To encode the scanned barcode for comparison
#import <RFIDEncoder/TIAIEncoder.h>  // To encode the scanned barcode for comparison

@interface DataViewController ()
@property (weak, nonatomic) IBOutlet UILabel *scannedBarcodeLbl;
@property (weak, nonatomic) IBOutlet UILabel *encodedBarcodeLbl;
@property (weak, nonatomic) IBOutlet UILabel *scannedRFIDLbl;
@property (weak, nonatomic) IBOutlet UILabel *gtinLbl;
@property (weak, nonatomic) IBOutlet UILabel *tcinLbl;
@property (weak, nonatomic) IBOutlet UILabel *departmentLbl;
@property (weak, nonatomic) IBOutlet UILabel *classLbl;
@property (weak, nonatomic) IBOutlet UILabel *itemLbl;
@property (weak, nonatomic) IBOutlet UILabel *serialLbl;
@property (weak, nonatomic) IBOutlet UILabel *tiaiLbl;
@property (weak, nonatomic) IBOutlet UILabel *aidLbl;
@property (weak, nonatomic) IBOutlet UILabel *versionLbl;

@end

@implementation DataViewController

@synthesize validTag;

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:0.65]

- (void)viewDidLoad {
    [super viewDidLoad];

    // Set the navigation bar background color to gray
    self.navigationController.navigationBar.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    
    // Do any additional setup after loading the view.
    _scannedBarcodeLbl.text = validTag.barcode;
    _encodedBarcodeLbl.text = validTag.encodedBarcode;
    _scannedRFIDLbl.text = validTag.rfid;
    _gtinLbl.text = [NSString stringWithFormat:@"GTIN: %@", validTag.gtin];
    _tcinLbl.text = [NSString stringWithFormat:@"TCIN: %@", validTag.tcin];
    _departmentLbl.text = [NSString stringWithFormat:@"Department: %@", validTag.dpt];
    _classLbl.text = [NSString stringWithFormat:@"Class: %@", validTag.cls];
    _itemLbl.text = [NSString stringWithFormat:@"Item: %@", validTag.itm];
    _serialLbl.text = [NSString stringWithFormat:@"Serial Number: %@", validTag.ser];
    _tiaiLbl.text = [NSString stringWithFormat:@"TIAI Ref: %@", validTag.tiai];
    _aidLbl.text = [NSString stringWithFormat:@"Asset ID: %@", validTag.aid];
    _versionLbl.text = [NSString stringWithFormat:@"ValiTag Version: %@",
                        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];

    // Set display fields
    _gtinLbl.hidden = YES;
    _tcinLbl.hidden = YES;
    _departmentLbl.hidden = YES;
    _classLbl.hidden = YES;
    _itemLbl.hidden = YES;
    _serialLbl.hidden = YES;
    _tiaiLbl.hidden = YES;
    _aidLbl.hidden = YES;
    
    // Nothing to do?
    if (!([validTag.rfidBin length] > 0)) {
        _departmentLbl.hidden = NO;
        _classLbl.hidden = NO;
        _itemLbl.hidden = NO;
        _serialLbl.hidden = NO;
        return;
    }
    
    // These are the only tags we recognize
    NSString *header = [validTag.rfidBin substringToIndex:8];
    BOOL validHeader = ([header isEqualToString:SGTIN_Bin_Prefix] ||
                        [header isEqualToString:GID_Bin_Prefix] ||
                        [header isEqualToString:TCIN_Bin_Prefix] ||
                        [header isEqualToString:TIAI_A_Bin_Prefix]);
    
    // Compare the binary formats: SGTIN = 58, GID = 60, TCIN = 46, TIAI = 96
    int length = 96;
    if ([header isEqualToString:SGTIN_Bin_Prefix]){
        _gtinLbl.hidden = NO;
        _serialLbl.hidden = NO;
        length = 58;
    }
    else if ([header isEqualToString:TCIN_Bin_Prefix]){
        _tcinLbl.hidden = NO;
        _serialLbl.hidden = NO;
        length = 46;
    }
    else if ([header isEqualToString:GID_Bin_Prefix]){
        _departmentLbl.hidden = NO;
        _classLbl.hidden = NO;
        _itemLbl.hidden = NO;
        _serialLbl.hidden = NO;
        length = 60;
    }
    else if ([header isEqualToString:TIAI_A_Bin_Prefix]){
        _tiaiLbl.hidden = NO;
        _aidLbl.hidden = NO;
        length = 96;
    }
    
    if (validHeader &&
        ([validTag.rfidBin length] > (length-1) && [validTag.encodedBarcodeBin length] > (length-1) &&
        [[validTag.rfidBin substringToIndex:(length-1)] isEqualToString:[validTag.encodedBarcodeBin substringToIndex:(length-1)]])) {
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
