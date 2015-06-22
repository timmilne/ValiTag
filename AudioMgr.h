//
//  Created by phychips on 2013. 3. 18.
//  Copyright (c) 2013 PHYCHIPS. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol AudioMgrDelegate;

@interface AudioMgr : NSObject
- (id)init;
- (BOOL)open;
- (BOOL)isOpened;
- (void)close;
- (BOOL)send:(NSData*)data;
@property (nonatomic, weak) id<AudioMgrDelegate> delegate;
@property (nonatomic) BOOL isConnected;
@end

@protocol AudioMgrDelegate <NSObject>
- (int)receive:(NSData *)data;
- (void) plugStatusChanged:(NSInteger)status;
@end
