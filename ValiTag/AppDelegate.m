//
//  AppDelegate.m
//  ValiTag
//
//  Created by Tim.Milne on 4/28/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import "AppDelegate.h"
#import "Ugi.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

@synthesize autoSaveAndExit;
@synthesize callBackApp;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    // Explicitly create the singleton for the uGrokit reader
    // We'll open the connection when the ScannerViewController is active
    [Ugi createSingleton];
    
// TPM - uncomment this for useful debugging info
//    [Ugi singleton].loggingStatus |= UGI_LOGGING_INTERNAL_PACKET_PROTOCOL;
    
    // Only true if invoked from another app
    [self setAutoSaveAndExit:NO];
    [self setCallBackApp:nil];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    
    // Release the uGrokit reader
    [Ugi releaseSingleton];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    NSLog(@"Calling Application Bundle ID: %@", sourceApplication);
    NSLog(@"URL scheme:%@", [url scheme]);
    NSLog(@"URL query: %@", [url query]);
    
    // Set the autoSaveAndExit flag
    [self setAutoSaveAndExit:YES];
    
    // Look for and save the calling app for a return call
    NSArray <NSString *> *queryArgs = [[url query] componentsSeparatedByString:@"&"];
    for (NSString *query in queryArgs) {
        if ([query containsString:@"callBackApp"]) {
            callBackApp = [query stringByReplacingOccurrencesOfString:@"callBackApp=" withString:@""];
            callBackApp = [callBackApp stringByAppendingString:@"://"];
            break;
        }
    }
    
    return YES;
}

- (void)returnToCaller {
    if (!autoSaveAndExit) return;
    if (!callBackApp) return;
    
    // iOS 10 +
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(openURL:options:completionHandler:)]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:callBackApp]
                                           options:@{}
                                 completionHandler:^(BOOL success) {
                                     NSLog(@"returnToCaller Success: %d",success);
                                 }];
        [self setAutoSaveAndExit:NO];
        [self setCallBackApp:nil];
    }
    else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:callBackApp]]) {
        if ([[UIApplication sharedApplication] openURL:[NSURL URLWithString:callBackApp]]) {
            NSLog(@"returnToCaller Success.");
            [self setAutoSaveAndExit:NO];
            [self setCallBackApp:nil];
        }
        else {
            NSLog(@"returnToCaller Failure.");
        }
    }
    else {
        NSLog(@"URL Error: No call back app found for: %@", callBackApp);
    }
}

@end
