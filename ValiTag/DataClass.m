//
//  DataClass.m
//  ValiTag
//
//  Created by Tim.Milne on 4/28/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import "DataClass.h"

@implementation DataClass

@synthesize barcode;
@synthesize rfid;

// The global data class
DataClass *data = nil;

static DataClass *instance = nil;

+(DataClass *)getInstance:(BOOL)reset {
    @synchronized(self){
        if(instance==nil){
            instance = [DataClass new];
            instance.barcode = [[NSMutableString alloc] init];
            instance.rfid = [[NSMutableString alloc] init];
            reset = TRUE;
        }
        if (reset == TRUE){
            [instance.barcode setString:@""];
            [instance.rfid setString:@""];
        }
    }
    return instance;
}

@end
