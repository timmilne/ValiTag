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
CheckDataObject *data = nil;

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
    data = [CheckDataObject singleton:FALSE];
    [encoder encodeObject:data.barcode              forKey:@"barcode"];
    [encoder encodeObject:data.encodedBarcode       forKey:@"encodedBarcode"];
    [encoder encodeObject:data.encodedBarcodeBin    forKey:@"encodedBarcodeBin"];
    [encoder encodeObject:data.rfid                 forKey:@"rfid"];
    [encoder encodeObject:data.rfidBin              forKey:@"rfidBin"];
    [encoder encodeObject:data.dpt                  forKey:@"dpt"];
    [encoder encodeObject:data.cls                  forKey:@"cls"];
    [encoder encodeObject:data.itm                  forKey:@"itm"];
    [encoder encodeObject:data.ser                  forKey:@"ser"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    data = [CheckDataObject singleton:FALSE];
    if (self = [super init]) {
        data.barcode            = [decoder decodeObjectForKey:@"barcode"];
        data.encodedBarcode     = [decoder decodeObjectForKey:@"encodedBarcode"];
        data.encodedBarcodeBin  = [decoder decodeObjectForKey:@"encodedBarcodeBin"];
        data.rfid               = [decoder decodeObjectForKey:@"rfid"];
        data.rfidBin            = [decoder decodeObjectForKey:@"rfidBin"];
        data.dpt                = [decoder decodeObjectForKey:@"dpt"];
        data.cls                = [decoder decodeObjectForKey:@"cls"];
        data.itm                = [decoder decodeObjectForKey:@"itm"];
        data.ser                = [decoder decodeObjectForKey:@"ser"];
    }
    return self;
}

@end
