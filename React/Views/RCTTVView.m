/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTTVView.h"

#import "RCTAutoInsetsProtocol.h"
#import "RCTBorderDrawing.h"
#import "RCTBridge.h"
#import "RCTConvert.h"
#import "RCTEventDispatcher.h"
#import "RCTLog.h"
#import "RCTRootViewInternal.h"
#import "RCTTVNavigationEventEmitter.h"
#import "RCTUtils.h"
#import "RCTView.h"
#import "UIView+React.h"

@implementation RCTTVView
{
  UITapGestureRecognizer *_selectRecognizer;
  BOOL _isChildFocused;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    self.tvParallaxProperties = @{
                                  @"enabled": @YES,
                                  @"shiftDistanceX": @2.0f,
                                  @"shiftDistanceY": @2.0f,
                                  @"tiltAngle": @0.05f,
                                  @"magnification": @1.0f
                                  };
  }
  
  return self;
}

RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:unused)

- (void)setIsTVSelectable:(BOOL)isTVSelectable {
  self->_isTVSelectable = isTVSelectable;
  if(isTVSelectable) {
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSelect:)];
    recognizer.allowedPressTypes = @[@(UIPressTypeSelect)];
    _selectRecognizer = recognizer;
    [self addGestureRecognizer:_selectRecognizer];
  } else {
    if(_selectRecognizer) {
      [self removeGestureRecognizer:_selectRecognizer];
    }
  }
}

- (void)handleSelect:(__unused UIGestureRecognizer *)r
{
  [[NSNotificationCenter defaultCenter] postNotificationName:RCTTVNavigationEventNotification
                                                      object:@{@"eventType":@"select",@"tag":self.reactTag}];
}

- (BOOL)isUserInteractionEnabled
{
  if (_isChildFocused) {
    return NO;
  }
  
  return YES;
}

- (BOOL)canBecomeFocused
{
  if (_isChildFocused) {
    return NO;
  }
  
  return (self.isTVSelectable);
}

- (void)addParallaxMotionEffects
{
  // Size of shift movements
  CGFloat const shiftDistanceX = [self.tvParallaxProperties[@"shiftDistanceX"] floatValue];
  CGFloat const shiftDistanceY = [self.tvParallaxProperties[@"shiftDistanceY"] floatValue];
  
  // Make horizontal movements shift the centre left and right
  UIInterpolatingMotionEffect *xShift = [[UIInterpolatingMotionEffect alloc]
                                         initWithKeyPath:@"center.x"
                                         type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
  xShift.minimumRelativeValue = @( shiftDistanceX * -1.0f);
  xShift.maximumRelativeValue = @( shiftDistanceX);
  
  // Make vertical movements shift the centre up and down
  UIInterpolatingMotionEffect *yShift = [[UIInterpolatingMotionEffect alloc]
                                         initWithKeyPath:@"center.y"
                                         type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
  yShift.minimumRelativeValue = @( shiftDistanceY * -1.0f);
  yShift.maximumRelativeValue = @( shiftDistanceY);
  
  // Size of tilt movements
  CGFloat const tiltAngle = [self.tvParallaxProperties[@"tiltAngle"] floatValue];
  
  // Now make horizontal movements effect a rotation about the Y axis for side-to-side rotation.
  UIInterpolatingMotionEffect *xTilt = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"layer.transform" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
  
  // CATransform3D value for minimumRelativeValue
  CATransform3D transMinimumTiltAboutY = CATransform3DIdentity;
  transMinimumTiltAboutY.m34 = 1.0 / 500;
  transMinimumTiltAboutY = CATransform3DRotate(transMinimumTiltAboutY, tiltAngle * -1.0, 0, 1, 0);
  
  // CATransform3D value for minimumRelativeValue
  CATransform3D transMaximumTiltAboutY = CATransform3DIdentity;
  transMaximumTiltAboutY.m34 = 1.0 / 500;
  transMaximumTiltAboutY = CATransform3DRotate(transMaximumTiltAboutY, tiltAngle, 0, 1, 0);
  
  // Set the transform property boundaries for the interpolation
  xTilt.minimumRelativeValue = [NSValue valueWithCATransform3D: transMinimumTiltAboutY];
  xTilt.maximumRelativeValue = [NSValue valueWithCATransform3D: transMaximumTiltAboutY];
  
  // Now make vertical movements effect a rotation about the X axis for up and down rotation.
  UIInterpolatingMotionEffect *yTilt = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"layer.transform" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
  
  // CATransform3D value for minimumRelativeValue
  CATransform3D transMinimumTiltAboutX = CATransform3DIdentity;
  transMinimumTiltAboutX.m34 = 1.0 / 500;
  transMinimumTiltAboutX = CATransform3DRotate(transMinimumTiltAboutX, tiltAngle * -1.0, 1, 0, 0);
  
  // CATransform3D value for minimumRelativeValue
  CATransform3D transMaximumTiltAboutX = CATransform3DIdentity;
  transMaximumTiltAboutX.m34 = 1.0 / 500;
  transMaximumTiltAboutX = CATransform3DRotate(transMaximumTiltAboutX, tiltAngle, 1, 0, 0);
  
  // Set the transform property boundaries for the interpolation
  yTilt.minimumRelativeValue = [NSValue valueWithCATransform3D: transMinimumTiltAboutX];
  yTilt.maximumRelativeValue = [NSValue valueWithCATransform3D: transMaximumTiltAboutX];
  
  // Add all of the motion effects to this group
  self.motionEffects = @[xShift, yShift, xTilt, yTilt];
  
  float magnification = [self.tvParallaxProperties[@"magnification"] floatValue];
  
  [UIView animateWithDuration:0.2 animations:^{
    self.transform = CGAffineTransformMakeScale(magnification, magnification);
  }];
}

- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context
{
  if (context.nextFocusedView == self && self.isTVSelectable) { // focus event
    
    
    if (_passTVFocusToChildren) { // parent getting focused
      
      if (!_isChildFocused) { // child is not focused so lets focus it
        
        UIView *childView = [self viewWithTag:_passTVFocusToChildren];
        
        if (childView.tag == _passTVFocusToChildren) { // if the tag matches we have our child that needs to be focused
          
          // so lets focus that child
          UIView *rootview = self;
          while (![rootview isReactRootView] && rootview != nil) {
            rootview = [rootview superview];
          }
          if (rootview == nil) return YES;
          
          rootview = [rootview superview];
          
          [(RCTRootView *)rootview setReactPreferredFocusedView:@[childView, context.nextFocusedView, context.previouslyFocusedView]];
          [rootview setNeedsFocusUpdate];
          [rootview updateFocusIfNeeded];
          
          // and set the flag on parent that says the child is focused so dont let me receive focus next time
          _isChildFocused = YES;
          
          return YES;
          
        } else { // children can be other views we dont want to focus so lets not focus on them
          
          return NO;
        }
        
      } else { // child is focused parent should not be receiving focus at all
        
      }
    } else if (_catchTVFocusFromParent) { // focusing children directly we should not allow it
      return NO;
    }
    
    // focusing non parent/children views
    
    UIView *rootview = self;
    while (![rootview isReactRootView] && rootview != nil) {
      rootview = [rootview superview];
    }
    if (rootview == nil) return YES;
    
    rootview = [rootview superview];
    
    [(RCTRootView *)rootview setReactPreferredFocusedView:@[context.nextFocusedView, context.previouslyFocusedView]];
    
    [rootview setNeedsFocusUpdate];
    [rootview updateFocusIfNeeded];
    
    return YES;
    
  } else { // blur event
    _isChildFocused = NO;
  }
  
  return YES;
  
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator
{
  if (context.nextFocusedView == self && self.isTVSelectable ) {
    [self becomeFirstResponder];
    [coordinator addCoordinatedAnimations:^(void){
      if([self.tvParallaxProperties[@"enabled"] boolValue]) {
        [self addParallaxMotionEffects];
      }
      [[NSNotificationCenter defaultCenter] postNotificationName:RCTTVNavigationEventNotification
                                                          object:@{@"eventType":@"focus",@"tag":self.reactTag}];
    } completion:^(void){}];
  } else {
    [coordinator addCoordinatedAnimations:^(void){
      [[NSNotificationCenter defaultCenter] postNotificationName:RCTTVNavigationEventNotification
                                                          object:@{@"eventType":@"blur",@"tag":self.reactTag}];
      [UIView animateWithDuration:0.2 animations:^{
        self.transform = CGAffineTransformMakeScale(1, 1);
      }];
      
      for (UIMotionEffect *effect in [self.motionEffects copy]){
        [self removeMotionEffect:effect];
      }
    } completion:^(void){}];
    [self resignFirstResponder];
  }
}

- (void)setHasTVPreferredFocus:(BOOL)hasTVPreferredFocus
{
  _hasTVPreferredFocus = hasTVPreferredFocus;
  if (hasTVPreferredFocus) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      UIView *rootview = self;
      while (![rootview isReactRootView] && rootview != nil) {
        rootview = [rootview superview];
      }
      if (rootview == nil) return;
      
      rootview = [rootview superview];
      
      [(RCTRootView *)rootview setReactPreferredFocusedView:@[self]];
      [rootview setNeedsFocusUpdate];
      [rootview updateFocusIfNeeded];
    });
  }
}

- (void)setPassTVFocusToChildren: (int) passTVFocusToChildren
{
  // store the child tag name to be able to find child and also to mark this view as a parent
  _passTVFocusToChildren = passTVFocusToChildren;
}

- (void)setCatchTVFocusFromParent: (int) catchTVFocusFromParent
{
  _catchTVFocusFromParent = catchTVFocusFromParent;
  
  if (_catchTVFocusFromParent) {
    // tag the child that will receive focus and mark this view as a child
    self.tag = _catchTVFocusFromParent;
  }
  
}

@end
