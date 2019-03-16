//
//  ValidTagObject.h
//  ValiTag
//
//  Created by Tim.Milne on 12/30/18.
//  Copyright © 2018 Tim.Milne. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ValidTagObject : NSObject

@property (nonatomic, retain) NSMutableString *barcode;
@property (nonatomic, retain) NSMutableString *encodedBarcode;
@property (nonatomic, retain) NSMutableString *encodedBarcodeBin;
@property (nonatomic, retain) NSMutableString *rfid;
@property (nonatomic, retain) NSMutableString *rfidBin;
@property (nonatomic, retain) NSMutableString *gtin;
@property (nonatomic, retain) NSMutableString *tcin;
@property (nonatomic, retain) NSMutableString *dpt;
@property (nonatomic, retain) NSMutableString *cls;
@property (nonatomic, retain) NSMutableString *itm;
@property (nonatomic, retain) NSMutableString *ser;
@property (nonatomic, retain) NSMutableString *tiai;
@property (nonatomic, retain) NSMutableString *aid;

@end
