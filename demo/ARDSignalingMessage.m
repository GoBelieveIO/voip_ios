/*
 *  Copyright 2014 The WebRTC Project Authors. All rights reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import "ARDSignalingMessage.h"

#import "WebRTC/RTCLogging.h"

#import "ARDUtilities.h"
#import "RTCIceCandidate+JSON.h"
#import "RTCSessionDescription+JSON.h"

static NSString const *kRTCICECandidateTypeKey = @"type";
static NSString const *kRTCICECandidateTypeValue = @"candidate";

static NSString * const kARDSignalingMessageTypeKey = @"type";
static NSString * const kARDTypeValueRemoveCandidates = @"remove-candidates";

@implementation ARDSignalingMessage

@synthesize type = _type;

- (instancetype)initWithType:(ARDSignalingMessageType)type {
  if (self = [super init]) {
    _type = type;
  }
  return self;
}

- (NSString *)description {
  return [[NSString alloc] initWithData:[self JSONData]
                               encoding:NSUTF8StringEncoding];
}

+ (ARDSignalingMessage *)messageFromDictionary:(NSDictionary *)values {
    
    NSString *typeString = values[kARDSignalingMessageTypeKey];
    ARDSignalingMessage *message = nil;
    if ([typeString isEqualToString:@"candidate"]) {
        RTCIceCandidate *candidate =
        [RTCIceCandidate candidateFromJSONDictionary:values];
        message = [[ARDICECandidateMessage alloc] initWithCandidate:candidate];
    } else if ([typeString isEqualToString:kARDTypeValueRemoveCandidates]) {
        RTCLogInfo(@"Received remove-candidates message");
        NSArray<RTCIceCandidate *> *candidates =
        [RTCIceCandidate candidatesFromJSONDictionary:values];
        message = [[ARDICECandidateRemovalMessage alloc]
                   initWithRemovedCandidates:candidates];
    } else if ([typeString isEqualToString:@"offer"] ||
               [typeString isEqualToString:@"answer"]) {
        RTCSessionDescription *description =
        [RTCSessionDescription descriptionFromJSONDictionary:values];
        message =
        [[ARDSessionDescriptionMessage alloc] initWithDescription:description];
    } else {
        RTCLogError(@"Unexpected type: %@", typeString);
    }
    return message;
}
+ (ARDSignalingMessage *)messageFromJSONString:(NSString *)jsonString {
  NSDictionary *values = [NSDictionary dictionaryWithJSONString:jsonString];
  if (!values) {
    RTCLogError(@"Error parsing signaling message JSON.");
    return nil;
  }
  return [self messageFromDictionary:values];
}

- (NSData *)JSONData {
  return nil;
}

- (NSDictionary*)JSONDictionary {
    return nil;
}
@end

@implementation ARDICECandidateMessage

@synthesize candidate = _candidate;

- (instancetype)initWithCandidate:(RTCIceCandidate *)candidate {
  if (self = [super initWithType:kARDSignalingMessageTypeCandidate]) {
    _candidate = candidate;
  }
  return self;
}

- (NSData *)JSONData {
  return [_candidate JSONData];
}

- (NSDictionary*)JSONDictionary {
    NSMutableDictionary *dict =  [NSMutableDictionary dictionaryWithDictionary:[_candidate JSONDictionary]];
    [dict setObject:kRTCICECandidateTypeValue forKey:kRTCICECandidateTypeKey];
    return dict;
}

@end

@implementation ARDICECandidateRemovalMessage

@synthesize candidates = _candidates;

- (instancetype)initWithRemovedCandidates:(
    NSArray<RTCIceCandidate *> *)candidates {
  NSParameterAssert(candidates.count);
  if (self = [super initWithType:kARDSignalingMessageTypeCandidateRemoval]) {
    _candidates = candidates;
  }
  return self;
}

- (NSData *)JSONData {
  return
      [RTCIceCandidate JSONDataForIceCandidates:_candidates
                                       withType:kARDTypeValueRemoveCandidates];
}

- (NSDictionary*)JSONDictionary {
    return
        [RTCIceCandidate JSONDictionaryForIceCandidates:_candidates
                                               withType:kARDTypeValueRemoveCandidates];
}
@end

@implementation ARDSessionDescriptionMessage

@synthesize sessionDescription = _sessionDescription;

- (instancetype)initWithDescription:(RTCSessionDescription *)description {
  ARDSignalingMessageType messageType = kARDSignalingMessageTypeOffer;
  RTCSdpType sdpType = description.type;
  switch (sdpType) {
    case RTCSdpTypeOffer:
      messageType = kARDSignalingMessageTypeOffer;
      break;
    case RTCSdpTypeAnswer:
      messageType = kARDSignalingMessageTypeAnswer;
      break;
    case RTCSdpTypePrAnswer:
      NSAssert(NO, @"Unexpected type: %@",
          [RTCSessionDescription stringForType:sdpType]);
      break;
  }
  if (self = [super initWithType:messageType]) {
    _sessionDescription = description;
  }
  return self;
}

- (NSData *)JSONData {
  return [_sessionDescription JSONData];
}

- (NSDictionary*)JSONDictionary {
    return [_sessionDescription JSONDictionary];
}
@end

