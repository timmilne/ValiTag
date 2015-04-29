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
@property (nonatomic, retain) NSMutableString *rfid;

+(DataClass*)getInstance:(BOOL)reset;

@end
