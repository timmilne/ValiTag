//
//  DataClass.h
//  ValiTag
//
//  Created by Tim.Milne on 4/28/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DataClass : NSObject

@property (nonatomic, retain) NSMutableString *barcode;
@property (nonatomic, retain) NSMutableString *encodedBarcode;
@property (nonatomic, retain) NSMutableString *encodedBarcodeBin;
@property (nonatomic, retain) NSMutableString *rfid;
@property (nonatomic, retain) NSMutableString *rfidBin;
@property (nonatomic, retain) NSMutableString *dpt;
@property (nonatomic, retain) NSMutableString *cls;
@property (nonatomic, retain) NSMutableString *itm;
@property (nonatomic, retain) NSMutableString *ser;

+(DataClass*)singleton:(BOOL)reset;

@end
