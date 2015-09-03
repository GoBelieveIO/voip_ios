/*
 * libjingle
 * Copyright 2013 Google Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "RTCI420Frame.h"

#include "webrtc/base/scoped_ptr.h"
#include "webrtc/video_frame.h"

@implementation RTCI420Frame {
    rtc::scoped_ptr<webrtc::VideoFrame> _videoFrame;
}

- (NSUInteger)width {
  return _videoFrame->width();
}

- (NSUInteger)height {
  return _videoFrame->height();
}

- (NSUInteger)chromaWidth {
   return (_videoFrame->width() + 1) / 2;
}

- (NSUInteger)chromaHeight {
   return (_videoFrame->height() + 1) / 2;
}

- (NSUInteger)chromaSize {
    
    return _videoFrame->stride(webrtc::kUPlane) * self.chromaHeight;

}

- (const uint8_t*)yPlane {
    return _videoFrame->buffer(webrtc::kYPlane);
}

- (const uint8_t*)uPlane {
    return _videoFrame->buffer(webrtc::kUPlane);
}

- (const uint8_t*)vPlane {
    return _videoFrame->buffer(webrtc::kVPlane);
}

- (NSInteger)yPitch {
    return _videoFrame->stride(webrtc::kYPlane);

}

- (NSInteger)uPitch {
        return _videoFrame->stride(webrtc::kUPlane);

}

- (NSInteger)vPitch {
        return _videoFrame->stride(webrtc::kVPlane);

}

- (BOOL)makeExclusive {
    return NO;
}

@end

@implementation RTCI420Frame (Internal)

- (instancetype)initWithVideoFrame:(webrtc::VideoFrame*)videoFrame {
  if (self = [super init]) {
    // Keep a shallow copy of the video frame. The underlying frame buffer is
    // not copied.
      webrtc::VideoFrame *p = new webrtc::VideoFrame();
      videoFrame->ShallowCopy(*p);
      _videoFrame.reset(p);
  }
  return self;
}

@end
