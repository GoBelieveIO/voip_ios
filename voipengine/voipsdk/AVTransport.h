#import <Foundation/Foundation.h>


@protocol VideoTransport
-(int)sendRTPPacketV:(const void*)data length:(int)length;
-(int)sendRTCPPacketV:(const void*)data length:(int)length STOR:(BOOL)STOR;

@end

@protocol VoiceTransport
-(int)sendRTPPacketA:(const void*)data length:(int)length;
-(int)sendRTCPPacketA:(const void*)data length:(int)length STOR:(BOOL)STOR;

@end
