/*                                                                            
  Copyright (c) 2014-2015, GoBelieve     
    All rights reserved.		    				     			
 
  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree. An additional grant
  of patent rights can be found in the PATENTS file in the same directory.
*/

#import <Foundation/Foundation.h>

@class VOIPTCP;
typedef void(^ConnectCB)(VOIPTCP *tcp, int err);
typedef void(^ReadCB)(VOIPTCP *tcp, NSData *data, int err);
typedef void(^CloseCB)(VOIPTCP *tcp, int err);

@interface VOIPTCP : NSObject
-(BOOL)connect:(NSString*)host port:(int)port cb:(ConnectCB)cb;
-(void)close;
-(void)write:(NSData*)data;
-(void)startRead:(ReadCB)cb;
@end


