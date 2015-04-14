/*                                                                            
  Copyright (c) 2014-2015, GoBelieve     
    All rights reserved.		    				     			
 
  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree. An additional grant
  of patent rights can be found in the PATENTS file in the same directory.
*/
#import <Foundation/Foundation.h>


@protocol VideoTransport
-(int)sendRTPPacketV:(const void*)data length:(int)length;
-(int)sendRTCPPacketV:(const void*)data length:(int)length STOR:(BOOL)STOR;

@end

@protocol VoiceTransport
-(int)sendRTPPacketA:(const void*)data length:(int)length;
-(int)sendRTCPPacketA:(const void*)data length:(int)length STOR:(BOOL)STOR;

@end
