//
//  ValidTagObject.m
//  ValiTag
//
//  Created by Tim.Milne on 12/30/18.
//  Copyright © 2018 Tim.Milne. All rights reserved.
//

#import "ValidTagObject.h"

@implementation ValidTagObject

@synthesize barcode;
@synthesize encodedBarcode;
@synthesize encodedBarcodeBin;
@synthesize rfid;
@synthesize rfidBin;
@synthesize dpt;
@synthesize cls;
@synthesize itm;
@synthesize ser;

- (ValidTagObject *) init {
    if (self = [super init]) {
        self.barcode = [[NSMutableString alloc] init];
        self.encodedBarcode = [[NSMutableString alloc] init];
        self.encodedBarcodeBin = [[NSMutableString alloc] init];
        self.rfid = [[NSMutableString alloc] init];
        self.rfidBin = [[NSMutableString alloc] init];
        self.dpt = [[NSMutableString alloc] init];
        self.cls = [[NSMutableString alloc] init];
        self.itm = [[NSMutableString alloc] init];
        self.ser = [[NSMutableString alloc] init];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.barcode              forKey:@"barcode"];
    [encoder encodeObject:self.encodedBarcode       forKey:@"encodedBarcode"];
    [encoder encodeObject:self.encodedBarcodeBin    forKey:@"encodedBarcodeBin"];
    [encoder encodeObject:self.rfid                 forKey:@"rfid"];
    [encoder encodeObject:self.rfidBin              forKey:@"rfidBin"];
    [encoder encodeObject:self.dpt                  forKey:@"dpt"];
    [encoder encodeObject:self.cls                  forKey:@"cls"];
    [encoder encodeObject:self.itm                  forKey:@"itm"];
    [encoder encodeObject:self.ser                  forKey:@"ser"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.barcode            = [decoder decodeObjectForKey:@"barcode"];
        self.encodedBarcode     = [decoder decodeObjectForKey:@"encodedBarcode"];
        self.encodedBarcodeBin  = [decoder decodeObjectForKey:@"encodedBarcodeBin"];
        self.rfid               = [decoder decodeObjectForKey:@"rfid"];
        self.rfidBin            = [decoder decodeObjectForKey:@"rfidBin"];
        self.dpt                = [decoder decodeObjectForKey:@"dpt"];
        self.cls                = [decoder decodeObjectForKey:@"cls"];
        self.itm                = [decoder decodeObjectForKey:@"itm"];
        self.ser                = [decoder decodeObjectForKey:@"ser"];
    }
    return self;
}

@end
