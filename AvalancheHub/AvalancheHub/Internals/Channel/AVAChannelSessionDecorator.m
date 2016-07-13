/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "AVAChannelSessionDecorator.h"
#import "AvalancheHub+Internal.h"
#import <UIKit/UIKit.h>

static NSTimeInterval const kAVASessionTimeOut = 20;

@interface AVAChannelSessionDecorator ()

/**
 *  Observer for event UIApplicationDidEnterBackgroundNotification
 */
@property(nonatomic, strong) id<NSObject> appWillEnterForegroundObserver;

/**
 *  Observer for event UIApplicationWillEnterForegroundNotification
 */
@property(nonatomic, strong) id<NSObject> appDidEnterBackgroundObserver;

/**
 *  Check if current session has timed out
 *
 *  @return YES if current session has timed out, NO otherwise
 */
- (BOOL)hasSessionTimedOut;

/**
 *  Register for application events
 */
- (void)registerObservers;

/**
 *  Unregister application events
 */
- (void)unregisterObservers;

@end

@implementation AVAChannelSessionDecorator

@synthesize batchSize = _batchSize;
@synthesize flushInterval = _flushInterval;

#pragma mark - Initialization

- (instancetype)initWithChannel:(id<AVAChannel>)channel {
  if (self = [self init]) {
    _channel = channel;
    _sessionTimeout = kAVASessionTimeOut;

    // Register for foregroung/background events
    [self registerObservers];
  }
  return self;
}

#pragma mark - Managing queue

- (void)enqueueItem:(id<AVALog>)item {

  // Check if new session id is required
  if (self.sid == nil || [self hasSessionTimedOut]) {
    _sid = kAVAUUIDString;
    AVALogVerbose(@"INFO:new session ID: %@", self.sid);
  }
  item.sid = self.sid;
  item.toffset =
      [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];

  // Set device log
  item.device = [self getDeviceLog];
  [self.channel enqueueItem:item];

  // Cache the queue timestamp
  self.lastQueuedLogTime = [NSDate date];
}

#pragma mark - Private methods

- (BOOL)hasSessionTimedOut {
  NSDate *now = [NSDate date];
  BOOL noLogSentForLong =
      [now timeIntervalSinceDate:self.lastQueuedLogTime] >= self.sessionTimeout;
  BOOL isBackgroundForLong =
      self.lastPausedTime >= self.lastResumedTime &&
      [now timeIntervalSinceDate:self.lastPausedTime] >= self.sessionTimeout;
  BOOL wasBackgroundForLong =
      [self.lastResumedTime timeIntervalSinceDate:self.lastPausedTime] >=
      self.sessionTimeout;
  return noLogSentForLong && (isBackgroundForLong || wasBackgroundForLong);
}

- (void)registerObservers {

  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  __weak typeof(self) weakSelf = self;

  if (nil == self.appDidEnterBackgroundObserver) {
    self.appDidEnterBackgroundObserver =
        [nc addObserverForName:UIApplicationDidEnterBackgroundNotification
                        object:nil
                         queue:NSOperationQueue.mainQueue
                    usingBlock:^(NSNotification *note) {
                      typeof(self) strongSelf = weakSelf;
                      [strongSelf applicationDidEnterBackground];
                    }];
  }
  if (nil == self.appWillEnterForegroundObserver) {
    self.appWillEnterForegroundObserver =
        [nc addObserverForName:UIApplicationWillEnterForegroundNotification
                        object:nil
                         queue:NSOperationQueue.mainQueue
                    usingBlock:^(NSNotification *note) {
                      typeof(self) strongSelf = weakSelf;
                      [strongSelf applicationWillEnterForeground];
                    }];
  }
}

- (void)unregisterObservers {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  self.appDidEnterBackgroundObserver = nil;
  self.appWillEnterForegroundObserver = nil;
}

- (void)applicationDidEnterBackground {
  self.lastPausedTime = [NSDate date];
}

- (void)applicationWillEnterForeground {
  self.lastResumedTime = [NSDate date];
}

- (AVADeviceLog *)getDeviceLog {
  // TODO use util funciton
  AVADeviceLog *device = [[AVADeviceLog alloc] init];
  
  return device;
}

@end