//
//  CheckDataObject.h
//  ValiTag
//
//  Created by Tim.Milne on 12/16/18.
//  Copyright © 2018 Tim.Milne. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CheckDataObject : NSObject <NSCoding>

@property (nonatomic, retain) NSMutableString *barcode;
@property (nonatomic, retain) NSMutableString *encodedBarcode;
@property (nonatomic, retain) NSMutableString *encodedBarcodeBin;
@property (nonatomic, retain) NSMutableString *rfid;
@property (nonatomic, retain) NSMutableString *rfidBin;
@property (nonatomic, retain) NSMutableString *dpt;
@property (nonatomic, retain) NSMutableString *cls;
@property (nonatomic, retain) NSMutableString *itm;
@property (nonatomic, retain) NSMutableString *ser;

+(CheckDataObject*)singleton:(BOOL)reset;

@end
