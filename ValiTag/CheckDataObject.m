//
//  CheckDataObject.m
//  ValiTag
//
//  Created by Tim.Milne on 12/16/18.
//  Copyright © 2018 Tim.Milne. All rights reserved.
//

#import "CheckDataObject.h"

@implementation CheckDataObject

@synthesize barcode;
@synthesize encodedBarcode;
@synthesize encodedBarcodeBin;
@synthesize rfid;
@synthesize rfidBin;
@synthesize dpt;
@synthesize cls;
@synthesize itm;
@synthesize ser;

// The singleton check data object
CheckDataObject *checkData = nil;

static CheckDataObject *instance = nil;

+(CheckDataObject *)singleton:(BOOL)reset {
    @synchronized(self){
        if(instance==nil){
            instance = [CheckDataObject new];
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

- (void)encodeWithCoder:(NSCoder *)encoder {
    checkData = [CheckDataObject singleton:FALSE];
    [encoder encodeObject:checkData.barcode              forKey:@"barcode"];
    [encoder encodeObject:checkData.encodedBarcode       forKey:@"encodedBarcode"];
    [encoder encodeObject:checkData.encodedBarcodeBin    forKey:@"encodedBarcodeBin"];
    [encoder encodeObject:checkData.rfid                 forKey:@"rfid"];
    [encoder encodeObject:checkData.rfidBin              forKey:@"rfidBin"];
    [encoder encodeObject:checkData.dpt                  forKey:@"dpt"];
    [encoder encodeObject:checkData.cls                  forKey:@"cls"];
    [encoder encodeObject:checkData.itm                  forKey:@"itm"];
    [encoder encodeObject:checkData.ser                  forKey:@"ser"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    checkData = [CheckDataObject singleton:FALSE];
    if (self = [super init]) {
        checkData.barcode            = [decoder decodeObjectForKey:@"barcode"];
        checkData.encodedBarcode     = [decoder decodeObjectForKey:@"encodedBarcode"];
        checkData.encodedBarcodeBin  = [decoder decodeObjectForKey:@"encodedBarcodeBin"];
        checkData.rfid               = [decoder decodeObjectForKey:@"rfid"];
        checkData.rfidBin            = [decoder decodeObjectForKey:@"rfidBin"];
        checkData.dpt                = [decoder decodeObjectForKey:@"dpt"];
        checkData.cls                = [decoder decodeObjectForKey:@"cls"];
        checkData.itm                = [decoder decodeObjectForKey:@"itm"];
        checkData.ser                = [decoder decodeObjectForKey:@"ser"];
    }
    return self;
}

@end
