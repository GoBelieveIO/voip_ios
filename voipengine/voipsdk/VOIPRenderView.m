//
//  VOIPRenderView.m
//  voipengine
//
//  Created by houxh on 15/8/31.
//  Copyright (c) 2015年 beetle. All rights reserved.
//

#import "VOIPRenderView.h"
#import "RTCEAGLVideoView.h"


@interface VOIPRenderView()<RTCEAGLVideoViewDelegate>

@property(nonatomic) RTCEAGLVideoView *rtcView;

@end
@implementation VOIPRenderView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

-(void*)getRTCView {
    return (__bridge void *)(self.rtcView);
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        CGRect f = CGRectMake(0, 0, frame.size.width, frame.size.height);
        self.rtcView = [[RTCEAGLVideoView alloc] initWithFrame:f];
        self.rtcView.delegate = self;
        [self addSubview:self.rtcView];
    }
    return self;
}

-(void)layoutSubviews {
    CGRect f = self.bounds;
    self.rtcView.frame = f;
}

- (void)videoView:(RTCEAGLVideoView*)videoView didChangeVideoSize:(CGSize)size {
    NSLog(@"size changed:%f %f", size.width, size.height);
}
@end
