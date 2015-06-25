//
//  EpcConverter.h
//  AreteAudio
//
//  Created by phychips on 2014. 7. 25..
//  Copyright (c) 2014년 phychips. All rights reserved.
//

#import <Foundation/Foundation.h>

#define HEX_STRING (0)
#define ASCII (1)
#define SGTIN96 (2)
#define EAN13 (3)

@interface EpcConverter : NSObject
+(NSString*) toHexString:(NSData*) data;
+(NSString*) toAscii:(NSData*) data;
+(NSString*) toEAN13:(NSData*) data;
+(NSString*) toSGTIN96:(NSData*) data;
+(NSString*) toString:(NSInteger)type data:(NSData*) data;
+(NSString*) toTypeString:(NSInteger)type;
@end
