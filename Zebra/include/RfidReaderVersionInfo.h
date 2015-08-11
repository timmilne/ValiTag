/******************************************************************************
 *
 *       Copyright Zebra Technologies, Inc. 2015
 *
 *       The copyright notice above does not evidence any
 *       actual or intended publication of such source code.
 *       The code contains Zebra Technologies
 *       Confidential Proprietary Information.
 *
 *
 *  Description:  RfidReaderVersionInfo.h
 *
 *  Notes:
 *
 ******************************************************************************/

#import <Foundation/Foundation.h>
#import "RfidSdkDefs.h"

@interface srfidReaderVersionInfo : NSObject
{
    NSString *m_DeviceVersion;
    NSString *m_BluetoothVersion;
    NSString *m_NGEVersion;
}

- (NSString*)getDeviceVersion;
- (void)setDeviceVersion:(NSString*)val;
- (NSString*)getBluetoothVersion;
- (void)setBluetoothVersion:(NSString*)val;
- (NSString*)getNGEVersion;
- (void)setNGEVersion:(NSString*)val;

@end

