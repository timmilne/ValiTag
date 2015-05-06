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
@synthesize encodedBarcode;
@synthesize encodedBarcodeBin;
@synthesize rfid;
@synthesize rfidBin;
@synthesize dpt;
@synthesize cls;
@synthesize itm;
@synthesize ser;

// The singleton data class
DataClass *data = nil;

static DataClass *instance = nil;

+(DataClass *)singleton:(BOOL)reset {
    @synchronized(self){
        if(instance==nil){
            instance = [DataClass new];
            instance.barcode = [[NSMutableString alloc] init];
            instance.encodedBarcode = [[NSMutableString alloc] init];
            instance.encodedBarcodeBin = [[NSMutableString alloc] init];
            instance.rfid = [[NSMutableString alloc] init];
            instance.rfidBin = [[NSMutableString alloc] init];
            instance.dpt = [[NSMutableString alloc] init];
            instance.cls = [[NSMutableString alloc] init];
            instance.itm = [[NSMutableString alloc] init];
            instance.ser = [[NSMutableString alloc] init];
            reset = TRUE;
        }
        if (reset == TRUE){
            [instance.barcode setString:@""];
            [instance.encodedBarcode setString:@""];
            [instance.encodedBarcodeBin setString:@""];
            [instance.rfid setString:@""];
            [instance.rfidBin setString:@""];
            [instance.dpt setString:@""];
            [instance.cls setString:@""];
            [instance.itm setString:@""];
            [instance.ser setString:@""];
        }
    }
    return instance;
}

@end
