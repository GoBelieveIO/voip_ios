#include <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AVTransport.h"

@interface AudioSendStream : NSObject {
}

@property (weak, nonatomic) id<VoiceTransport> voiceTransport;

@property(assign, nonatomic)int voiceChannel;

-(BOOL)start;
-(BOOL)stop;
@end

@class VOIPRenderView;

@interface AVSendStream : NSObject {
}
@property (weak, nonatomic) VOIPRenderView *render;
@property (weak, nonatomic) id<VoiceTransport> voiceTransport;
@property(assign, nonatomic)int voiceChannel;

@property(nonatomic) int32_t videoSSRC;
@property(nonatomic) int32_t voiceSSRC;

-(void)setCall:(void*)call;

-(void)sendKeyFrame;
-(BOOL)start;
-(BOOL)stop;
@end

