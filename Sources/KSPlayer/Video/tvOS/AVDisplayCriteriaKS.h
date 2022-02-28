//
//  AVDisplayCriteriaKS.h
//  KSPlayer
//
//  Created by Alanko5 on 07/01/2022.
//

#ifndef AVDisplayCriteriaKS_h
#define AVDisplayCriteriaKS_h

#import <AVFoundation/AVDisplayCriteria.h>

@interface AVDisplayCriteria ()
@property(readonly) int videoDynamicRange;
@property(readonly, nonatomic) float refreshRate;
- (id)initWithRefreshRate:(float)arg1 videoDynamicRange:(int)arg2;
@end

#endif /* AVDisplayCriteriaKS_h */
