//
//  AVDisplayCriteriaKS.h
//  KSPlayer
//
//  Created by kintan on 2022/8/28.
//

#ifndef AVDisplayCriteriaKS_h
#define AVDisplayCriteriaKS_h
#if __has_include(<AVFoundation/AVDisplayCriteria.h>)
#import <AVFoundation/AVDisplayCriteria.h>
@interface AVDisplayCriteria ()
@property(readonly) int videoDynamicRange;
@property(readonly, nonatomic) float refreshRate;
- (id)initWithRefreshRate:(float)arg1 videoDynamicRange:(int)arg2;
@end
#endif

#if __has_include(<AppKit/AppKit.h>) && !TARGET_OS_MACCATALYST
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

#pragma mark - CoreDisplay.framework

extern CFDictionaryRef _Nullable CoreDisplay_DisplayCreateInfoDictionary(CGDirectDisplayID display);

#pragma mark - PIP.framework

NS_ASSUME_NONNULL_BEGIN

@protocol PIPViewControllerDelegate;

@interface PIPViewController : NSViewController

@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, weak, nullable) id<PIPViewControllerDelegate> delegate;
@property (nonatomic, weak, nullable) NSWindow *replacementWindow;
@property (nonatomic) NSRect replacementRect;
@property (nonatomic) bool playing;
@property (nonatomic) NSSize aspectRatio;

- (void)presentViewControllerAsPictureInPicture:(NSViewController *)viewController;

@end

@protocol PIPViewControllerDelegate <NSObject>

@optional
// it seems the system doesn't call this function since macOS 10.15
- (BOOL)pipShouldClose:(PIPViewController *)pip __OSX_AVAILABLE_STARTING(__MAC_10_12,__IPHONE_NA);
// instead this is added in macOS 10.15
- (void)pipWillClose:(PIPViewController *)pip __OSX_AVAILABLE_STARTING(__MAC_10_12,__IPHONE_NA);
- (void)pipDidClose:(PIPViewController *)pip __OSX_AVAILABLE_STARTING(__MAC_10_12,__IPHONE_NA);
- (void)pipActionPlay:(PIPViewController *)pip __OSX_AVAILABLE_STARTING(__MAC_10_12,__IPHONE_NA);
- (void)pipActionPause:(PIPViewController *)pip __OSX_AVAILABLE_STARTING(__MAC_10_12,__IPHONE_NA);
- (void)pipActionStop:(PIPViewController *)pip __OSX_AVAILABLE_STARTING(__MAC_10_12,__IPHONE_NA);
@end

NS_ASSUME_NONNULL_END
#endif
#endif /* AVDisplayCriteriaKS_h */
