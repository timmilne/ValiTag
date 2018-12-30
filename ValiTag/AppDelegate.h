//
//  AppDelegate.h
//  ValiTag
//
//  Created by Tim.Milne on 4/28/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow  *window;

// OpenURL support
// Scan Scan Save and Return
@property                     BOOL      autoSaveAndExit;
@property                     BOOL      scanScanSaveReturn;
@property (strong, nonatomic) NSString  *dataFile;

// Scan and confirm, manual return (preload one or both to check)
@property                     BOOL      scanConfirm;
@property (strong, nonatomic) NSString  *rfid;
@property (strong, nonatomic) NSString  *barcode;

// The callback
@property (strong, nonatomic) NSString  *callBackApp;

- (void)returnToCaller;

@end

