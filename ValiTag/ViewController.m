//
//  ViewController.m
//  ValiTag
//
//  Created by Tim.Milne on 4/28/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import "ViewController.h"
#import "DataClass.h" // Singleton data class

#pragma mark -
#pragma mark AVFoundationScanSetup

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *barcode_fld;
@property (weak, nonatomic) IBOutlet UILabel *rfid_fld;

@end

// The global data class
extern DataClass *data;

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // Grab the data class
    if (data == nil) data = [DataClass getInstance:FALSE];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)unwindToContainerVC:(UIStoryboardSegue *)segue {
    // Update the labels
    [self.barcode_fld setText:data.barcode];
    
}

@end
