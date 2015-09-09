#import <Foundation/Foundation.h>

@protocol VoiceTransport
-(int)sendRTPPacketA:(const void*)data length:(int)length;
-(int)sendRTCPPacketA:(const void*)data length:(int)length STOR:(BOOL)STOR;

@end
