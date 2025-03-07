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
@synthesize gtin;
@synthesize tcin;
@synthesize dpt;
@synthesize cls;
@synthesize itm;
@synthesize ser;
@synthesize tiai;
@synthesize aid;

- (ValidTagObject *) init {
    if (self = [super init]) {
        self.barcode = [[NSMutableString alloc] init];
        self.encodedBarcode = [[NSMutableString alloc] init];
        self.encodedBarcodeBin = [[NSMutableString alloc] init];
        self.rfid = [[NSMutableString alloc] init];
        self.rfidBin = [[NSMutableString alloc] init];
        self.gtin = [[NSMutableString alloc] init];
        self.tcin = [[NSMutableString alloc] init];
        self.dpt = [[NSMutableString alloc] init];
        self.cls = [[NSMutableString alloc] init];
        self.itm = [[NSMutableString alloc] init];
        self.ser = [[NSMutableString alloc] init];
        self.tiai = [[NSMutableString alloc] init];
        self.aid = [[NSMutableString alloc] init];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.barcode              forKey:@"barcode"];
    [encoder encodeObject:self.encodedBarcode       forKey:@"encodedBarcode"];
    [encoder encodeObject:self.encodedBarcodeBin    forKey:@"encodedBarcodeBin"];
    [encoder encodeObject:self.rfid                 forKey:@"rfid"];
    [encoder encodeObject:self.rfidBin              forKey:@"rfidBin"];
    [encoder encodeObject:self.gtin                 forKey:@"gtin"];
    [encoder encodeObject:self.tcin                 forKey:@"tcin"];
    [encoder encodeObject:self.dpt                  forKey:@"dpt"];
    [encoder encodeObject:self.cls                  forKey:@"cls"];
    [encoder encodeObject:self.itm                  forKey:@"itm"];
    [encoder encodeObject:self.ser                  forKey:@"ser"];
    [encoder encodeObject:self.tiai                 forKey:@"tiai"];
    [encoder encodeObject:self.aid                  forKey:@"aid"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.barcode            = [decoder decodeObjectOfClass:[NSString class] forKey:@"barcode"];
        self.encodedBarcode     = [decoder decodeObjectOfClass:[NSString class] forKey:@"encodedBarcode"];
        self.encodedBarcodeBin  = [decoder decodeObjectOfClass:[NSString class] forKey:@"encodedBarcodeBin"];
        self.rfid               = [decoder decodeObjectOfClass:[NSString class] forKey:@"rfid"];
        self.rfidBin            = [decoder decodeObjectOfClass:[NSString class] forKey:@"rfidBin"];
        self.gtin               = [decoder decodeObjectOfClass:[NSString class] forKey:@"gtin"];
        self.tcin               = [decoder decodeObjectOfClass:[NSString class] forKey:@"tcin"];
        self.dpt                = [decoder decodeObjectOfClass:[NSString class] forKey:@"dpt"];
        self.cls                = [decoder decodeObjectOfClass:[NSString class] forKey:@"cls"];
        self.itm                = [decoder decodeObjectOfClass:[NSString class] forKey:@"itm"];
        self.ser                = [decoder decodeObjectOfClass:[NSString class] forKey:@"ser"];
        self.tiai               = [decoder decodeObjectOfClass:[NSString class] forKey:@"tiai"];
        self.aid                = [decoder decodeObjectOfClass:[NSString class] forKey:@"aid"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding {
   return YES;
}

@end
