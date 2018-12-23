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
@property                     BOOL      autoSaveAndExit;
@property (strong, nonatomic) NSString  *callBackApp;
@property (strong, nonatomic) NSString  *dataFile;
- (void)returnToCaller;

@end

