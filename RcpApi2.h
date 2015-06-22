//
//  RcpApi2.h
//  AreteAudio
//
//  Created by phychips on 2014. 5. 19..
//  Copyright (c) 2013 PHYCHIPS. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "AudioMgr.h"

@protocol RcpDelegate2;

@interface RcpApi2 : NSObject <AudioMgrDelegate>
+ (RcpApi2*)sharedInstance;

- (BOOL)submitPassword:(NSString*)password;
- (BOOL)open;
- (BOOL)isOpened;
- (void)close;
- (BOOL)isPlugged;

- (BOOL)startReadTags:(uint8_t)maxTags mtime:(uint8_t)maxTime repeatCycle:(uint16_t)repeatCycle;
- (BOOL)startReadTagsWithRssi:(uint8_t)maxTags mtime:(uint8_t)maxTime repeatCycle:(uint16_t)repeatCycle;
- (BOOL)startReadTagsWithTid:(uint8_t)mtnu mtime:(uint8_t)mtime repeatCycle:(uint16_t)repeatCycle;
- (BOOL)stopReadTags;

- (BOOL)getRegion;
- (BOOL)getReaderInfo:(uint8_t)infoType;

- (BOOL)getSelectParam;
- (BOOL)setSelectParam:(uint8_t)target 
	action:(uint8_t)action 
	memoryBank:(uint8_t)memoryBank 
	pointer:(uint32_t)pointer 
	length:(uint8_t)length 
	mask:(NSData *)mask;

- (BOOL)getQueryParam;

- (BOOL)getChannel;
- (BOOL)setChannel:(uint8_t)channel
     channelOffset:(uint8_t)channelOffset;

- (BOOL)getSession;
- (BOOL)setSession:(uint8_t)session;

- (BOOL)getFhLbtParam;
- (BOOL)setFhLbtParam:(uint16_t)readTime 
		idleTime:(uint16_t)idleTime 
		carrierSenseTime:(uint16_t) carrierSenseTime 
		rfLevel:(uint16_t)rfLevel 
		frequencyHopping:(uint8_t)frequencyHopping 
		listenBeforeTalk:(uint8_t)listenBeforeTalk 
		continuousWave:(uint8_t)continuousWave;

- (BOOL)getOutputPowerLevel;
- (BOOL)setOutputPowerLevel:(uint16_t)power;

- (BOOL)readFromTagMemory:(uint32_t)accessPassword
		epc:(NSData*)epc
		memoryBank:(uint8_t)memoryBank
		startAddress:(uint16_t)startAddress
		dataLength:(uint16_t)dataLength;
- (BOOL)writeToTagMemory:(uint32_t)accessPassword
		epc:(NSData*)epc
		memoryBank:(uint8_t)memoryBank
		startAddress:(uint16_t)startAddress
		dataToWrite:(NSData*)dataToWrite;
- (BOOL)killTag:(uint32_t)killPassword
		epc:(NSData*)epc;
- (BOOL)lockTagMemory:(uint32_t)accessPassword
		epc:(NSData*)epc
		lockData:(uint32_t)lockData;

- (BOOL)setBeep:(uint8_t)on;
- (BOOL)genericTrasport:(uint8_t)TS
        ap:(uint32_t)accessPassword
        RM:(uint8_t)RM
        epc:(NSData*)epc
        SZ :(uint8_t)SZ
        GC:(NSData*)GC;
- (BOOL)calGpAdc:(uint8_t)min max:(uint8_t)max;

@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, weak) id<RcpDelegate2> delegate;
@end

@protocol RcpDelegate2 <NSObject>
@optional
- (void)plugged:(BOOL)plug;
- (void)resetReceived;
- (void)successReceived:(NSData *)data commandCode:(uint8_t)commandCode;
- (void)failureReceived:(NSData *)errCode;
- (void)tagReceived:(NSData *)pcEpc;
- (void)tagWithRssiReceived:(NSData *)pcEpc rssi:(int8_t)rssi;
- (void)tagWithTidReceived:(NSData *)pcEpc tid:(NSData *)tid;
- (void)readerInfoReceived:(NSData *)data;
- (void)regionReceived:(uint8_t)region;
- (void)selectParamReceived:(NSData *)selParam;
- (void)queryParamReceived:(NSData *)qryParam;
- (void)channelReceived:(uint8_t)channel channelOffset:(uint8_t)channelOffset;
- (void)sessionReceived:(uint8_t)session;
- (void)fhLbtReceived:(NSData *)fhLb;
- (void)txPowerLevelReceived:(uint8_t)power;
- (void)tagMemoryReceived:(NSData *)data;
- (void)batteryStateReceived:(NSData*)data;
- (void)genericReceived:(NSData*)data;
@end

