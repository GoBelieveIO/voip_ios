/*
 Copyright (c) 2014-2015, GoBelieve
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVMediaFormat.h>

#import "VOIPCapture.h"

#import "WebRTC.h"
#include "webrtc/modules/video_capture/video_capture_factory.h"
#include "webrtc/modules/video_capture/video_capture.h"
#include "webrtc/voice_engine/include/voe_network.h"
#include "webrtc/voice_engine/include/voe_audio_processing.h"
#include "webrtc/voice_engine/include/voe_hardware.h"
#import "VOIPRenderView.h"
#import "RTCI420Frame+Internal.h"
#import "RTCI420Frame.h"
#import "RTCEAGLVideoView.h"


#define ARRAY_SIZE(x) (static_cast<int>(sizeof(x) / sizeof(x[0])))

class WebRtcVcmFactory {
public:
    virtual webrtc::VideoCaptureModule* Create(int id, const char* device) {
        return webrtc::VideoCaptureFactory::Create(id, device);
    }
    virtual webrtc::VideoCaptureModule::DeviceInfo* CreateDeviceInfo(int id) {
        return webrtc::VideoCaptureFactory::CreateDeviceInfo(id);
    }
    virtual void DestroyDeviceInfo(webrtc::VideoCaptureModule::DeviceInfo* info) {
        delete info;
    }
};


class VideoCaptureDataCallback:public webrtc::VideoCaptureDataCallback {
public:
    // Callback when a frame is captured by camera.
    virtual void OnIncomingCapturedFrame(const int32_t id,
                                         const webrtc::VideoFrame& frame) {
        [capture.delegate onIncomingCapturedFrame:(void*)&frame];
        
        if (capture.render) {
            
            RTCEAGLVideoView *rtcView = (__bridge RTCEAGLVideoView*)[capture.render getRTCView];
            
            RTCI420Frame *f = [[RTCI420Frame alloc] initWithVideoFrame:&frame];
            
            [rtcView renderFrame:f];
        }
    }
    virtual void OnCaptureDelayChanged(const int32_t id,
                                       const int32_t delay) {
        
    }
    
    __weak VOIPCapture *capture;
    
    VideoCaptureDataCallback(VOIPCapture *s):capture(s) {}
};


class VideoCaptureDataCallback;
@interface VOIPCapture() {
    webrtc::VideoCaptureModule* module_;
    WebRtcVcmFactory *factory_;
    VideoCaptureDataCallback *cb_;
}

@end

@implementation VOIPCapture

- (id)init {
    self = [super init];
    if (self) {
        factory_ = new WebRtcVcmFactory();
        cb_ = new VideoCaptureDataCallback(self);
        self.frontCamera = YES;
    }
    return self;
}

- (void)dealloc {
    delete cb_;
    delete factory_;
}

- (BOOL)startCapture {
    return [self startCapture:self.isFrontCamera];
}

- (BOOL)startCapture:(BOOL)front {
    if (module_ != NULL) {
        NSLog(@"can't start capture, module is't null");
        return NO;
    }
    
    AVCaptureDevice *device;
    for (AVCaptureDevice *captureDevice in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] ) {
        if (front && captureDevice.position == AVCaptureDevicePositionFront) {
            device = captureDevice;
            break;
        } else if (!front && captureDevice.position == AVCaptureDevicePositionBack) {
            device = captureDevice;
            break;
        }
    }
    NSLog(@"device:%@ %@", device.uniqueID, device.localizedName);
    
    const char *device_name = [device.localizedName UTF8String];
    
    webrtc::VideoCaptureModule::DeviceInfo* info = factory_->CreateDeviceInfo(0);
    if (!info) {
        return NO;
    }
    
    int num_cams = info->NumberOfDevices();
    char vcm_id[256] = "";
    bool found = false;
    for (int index = 0; index < num_cams; ++index) {
        char vcm_name[256] = {0};
        if (info->GetDeviceName(index, vcm_name, ARRAY_SIZE(vcm_name),
                                vcm_id, ARRAY_SIZE(vcm_id)) != -1) {
            
            NSLog(@"vcm name:%s", vcm_name);
            if (strcmp(vcm_name, device_name) == 0) {
                found = true;
                break;
            }
        }
    }
    
    if (!found) {
        NSLog(@"Failed to find capturer for name:%s", device_name);
        factory_->DestroyDeviceInfo(info);
        return NO;
    }
    
    webrtc::VideoCaptureCapability best_cap;
    best_cap.width = WIDTH;
    best_cap.height = HEIGHT;
    best_cap.maxFPS = FPS;
    best_cap.rawType = webrtc::kVideoNV12;
    
    int best_diff = INT_MAX;
    
    int32_t num_caps = info->NumberOfCapabilities(vcm_id);
    for (int32_t i = 0; i < num_caps; ++i) {
        webrtc::VideoCaptureCapability cap;
        if (info->GetCapability(vcm_id, i, cap) != -1) {
            NSLog(@"cap width:%d height:%d raw type:%d max fps:%d", cap.width, cap.height, cap.rawType, cap.maxFPS);
        }
        
        int area = cap.width*cap.height;
        int diff = abs(area - WIDTH*HEIGHT);
        
        if (diff < best_diff) {
            best_cap = cap;
            best_diff = diff;
        }
    }
    
    NSLog(@"best cap width:%d height:%d raw type:%d max fps:%d",
          best_cap.width, best_cap.height, best_cap.rawType, best_cap.maxFPS);
    
    factory_->DestroyDeviceInfo(info);
    
    
    module_ = factory_->Create(0, vcm_id);
    if (!module_) {
        NSLog(@"Failed to create capturer for name:%s ", device_name);
        return NO;
    }
    
    // It is safe to change member attributes now.
    module_->AddRef();
    
    
    module_->RegisterCaptureDataCallback(*cb_);
    if (module_->StartCapture(best_cap) != 0) {
        module_->DeRegisterCaptureDataCallback();
        return NO;
    }
    
    return YES;
}

- (void)stopCapture {
    if (module_ != NULL) {
        module_->DeRegisterCaptureDataCallback();
        module_->StopCapture();
        
        module_->Release();
        module_ = NULL;
    }
}

-(void)switchCamera {
    [self stopCapture];
    
    self.frontCamera = !self.isFrontCamera;
    [self startCapture:self.isFrontCamera];
}

@end
