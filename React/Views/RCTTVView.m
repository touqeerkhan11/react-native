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
  NSLog(@"❤️next view: %ld", (long)context.nextFocusedView.tag);
  NSLog(@"❤️prev view: %ld", (long)context.previouslyFocusedView.tag);
  
  if (context.nextFocusedView == self && self.isTVSelectable) {
    
    if (_passTVFocusToChildren) {
      UIView *childView = [self viewWithTag:_passTVFocusToChildren];
      
      if (childView.tag == _passTVFocusToChildren) {
        
        if (childView.tag == context.previouslyFocusedView.tag) {
          _isChildFocused = NO;
          
          UIView *rootview = self;
          while (![rootview isReactRootView] && rootview != nil) {
            rootview = [rootview superview];
          }
          if (rootview == nil) return YES;
          
          rootview = [rootview superview];
          
          [(RCTRootView *)rootview setReactPreferredFocusedView:childView];
          [rootview setNeedsFocusUpdate];
          [rootview updateFocusIfNeeded];
          
          return NO;
        }
        
        UIView *rootview = self;
        while (![rootview isReactRootView] && rootview != nil) {
          rootview = [rootview superview];
        }
        if (rootview == nil) return YES;
        
        rootview = [rootview superview];
        
        [(RCTRootView *)rootview setReactPreferredFocusedView:childView];
        [rootview setNeedsFocusUpdate];
        [rootview updateFocusIfNeeded];
        
        _isChildFocused = YES;
        
        return YES;
      } else {
        return YES;
      }
      
      //      NSLog(@"😈😈 passing focus %ld", (long)childView.tag);
      
      //      [self resignFirstResponder];
      //      [childView becomeFirstResponder];
      
      //        [childView focusItemContainer];
    } else {
      _isChildFocused = NO;
      return YES;
    }
  } else {
    _isChildFocused = NO;
    return YES;
  }
  
  
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
    } completion:^(void){
      
      //      NSLog(@"😈 parent: %d, child: %d", _passTVFocusToChildren, _catchTVFocusFromParent);
      //
      //      if (_passTVFocusToChildren) {
      //
      //        UIView *childView = [self viewWithTag:_passTVFocusToChildren];
      //
      //        NSLog(@"😈😈 passing focus %ld", (long)childView.tag);
      //
      ////        [childView shouldUpdateFocusInContext:context];
      ////        [self resignFirstResponder];
      ////        [childView becomeFirstResponder];
      //
      ////        [childView focusItemContainer];
      //      }
    }];
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
      
      [(RCTRootView *)rootview setReactPreferredFocusedView:self];
      [rootview setNeedsFocusUpdate];
      [rootview updateFocusIfNeeded];
    });
  }
}

- (void)setPassTVFocusToChildren: (int) passTVFocusToChildren
{
  _passTVFocusToChildren = passTVFocusToChildren;
  
  //  NSLog(@"😈 setting parent %d", _passTVFocusToChildren);
  
  //  _parent = _passTVFocusToChildren;
  //  _passTVFocusToChildren = 786;
}

- (void)setCatchTVFocusFromParent: (int) catchTVFocusFromParent
{
  _catchTVFocusFromParent = catchTVFocusFromParent;
  
  //  _child = catchTVFocusFromParent;
  
  if (_catchTVFocusFromParent) {
    //    NSLog(@"😈 setting child %d", _catchTVFocusFromParent);
    
    self.tag = _catchTVFocusFromParent;
  }
  
}

@end
