/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTTabBar.h"

#import "RCTEventDispatcher.h"
#import "RCTLog.h"
#import "RCTTabBarItem.h"
#import "RCTUtils.h"
#import "RCTView.h"
#import "RCTWrapperViewController.h"
#import "UIView+React.h"

#if defined(__TV_OS_VERSION_MAX_ALLOWED) && defined(__TVOS_13_0) && __TV_OS_VERSION_MAX_ALLOWED >= __TVOS_13_0

// For tvOS 13.0 and higher, we need to explicitly set an animation for transitions
// from one tab to another, otherwise the transition is choppy
@interface TransitionAnimator: NSObject<UIViewControllerAnimatedTransitioning>

@end

@implementation TransitionAnimator

- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext {
    return 1.0f;
    }

- (void)animateTransition:(id <UIViewControllerContextTransitioning>)transitionContext     {
    // Grab the from and to view controllers from the context
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];

    // Set our ending frame. We'll modify this later if we have to
    CGRect endFrame = CGRectMake(0, 0, 1920, 1080);


    toViewController.view.userInteractionEnabled = YES;

    [transitionContext.containerView addSubview:toViewController.view];
    [transitionContext.containerView addSubview:fromViewController.view];

    endFrame.origin.x += 1920;

    [UIView animateWithDuration:0.5 animations:^{
        // toViewController.view.tintAdjustmentMode = UIViewTintAdjustmentModeAutomatic;
        // fromViewController.view.frame = endFrame;
        fromViewController.view.layer.opacity = 0.0;
    } completion:^(BOOL finished) {
        fromViewController.view.layer.opacity = 1.0;
        [transitionContext completeTransition:YES];
    }];
}

@end

#endif

@interface RCTTabBar() <UITabBarControllerDelegate>

#if defined(__TV_OS_VERSION_MAX_ALLOWED) && defined(__TVOS_13_0) && __TV_OS_VERSION_MAX_ALLOWED >= __TVOS_13_0
@property(nonatomic, strong, nullable) UITabBarAppearance *appearance;
#endif

@end

@implementation RCTTabBar
{
  BOOL _tabsChanged;
  UITabBarController *_tabController;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
      _tabController = [UITabBarController new];
      _tabController.delegate = self;
      [self addSubview:_tabController.view];
        if (@available(iOS 13.0, tvOS 13.0, *)) {
            self.appearance = [[UITabBarAppearance alloc] init];
            [self.appearance configureWithTransparentBackground];
            _tabController.tabBar.standardAppearance = self.appearance;
        }
    }
    return self;
}

RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:(NSCoder *)aDecoder)

- (UIViewController *)reactViewController
{
  return _tabController;
}

- (void)dealloc
{
  _tabController.delegate = nil;
  [_tabController removeFromParentViewController];
}

- (void)insertReactSubview:(RCTTabBarItem *)subview atIndex:(NSInteger)atIndex
{
  if (![subview isKindOfClass:[RCTTabBarItem class]]) {
    RCTLogError(@"subview should be of type RCTTabBarItem");
    return;
  }
  [super insertReactSubview:subview atIndex:atIndex];
  _tabsChanged = YES;
}

- (void)removeReactSubview:(RCTTabBarItem *)subview
{
  if (self.reactSubviews.count == 0) {
    RCTLogError(@"should have at least one view to remove a subview");
    return;
  }
  [super removeReactSubview:subview];
  _tabsChanged = YES;
}

- (void)didUpdateReactSubviews
{
  // Do nothing, as subviews are managed by `uiManagerDidPerformMounting`
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  [self reactAddControllerToClosestParent:_tabController];
  _tabController.view.frame = self.bounds;
}

- (void)uiManagerDidPerformMounting
{
  // we can't hook up the VC hierarchy in 'init' because the subviews aren't
  // hooked up yet, so we do it on demand here whenever a transaction has finished
  [self reactAddControllerToClosestParent:_tabController];

  if (_tabsChanged) {

    NSMutableArray<UIViewController *> *viewControllers = [NSMutableArray array];
    for (RCTTabBarItem *tab in [self reactSubviews]) {
      UIViewController *controller = tab.reactViewController;
      if (!controller) {
        controller = [[RCTWrapperViewController alloc] initWithContentView:tab];
      }
      [viewControllers addObject:controller];
    }

    _tabController.viewControllers = viewControllers;
    _tabsChanged = NO;
  }

  [self.reactSubviews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger index, __unused BOOL *stop) {

    RCTTabBarItem *tab = (RCTTabBarItem *)view;
    UIViewController *controller = self->_tabController.viewControllers[index];
    if (self->_unselectedTintColor) {
      [tab.barItem setTitleTextAttributes:@{NSForegroundColorAttributeName: self->_unselectedTintColor} forState:UIControlStateNormal];
    }

    [tab.barItem setTitleTextAttributes:@{NSForegroundColorAttributeName: self.tintColor} forState:UIControlStateSelected];

    controller.tabBarItem = tab.barItem;
#if TARGET_OS_TV
// On Apple TV, disable JS control of selection after initial render
    if (tab.selected && !tab.wasSelectedInJS) {
      self->_tabController.selectedViewController = controller;
    }
    tab.wasSelectedInJS = YES;
#else
    if (tab.selected) {
      self->_tabController.selectedViewController = controller;
    }
#endif
  }];
}

- (UIColor *)barTintColor
{
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        return _tabController.tabBar.standardAppearance.backgroundColor;
    } else {
        return _tabController.tabBar.barTintColor;
    }
}

- (void)setBarTintColor:(UIColor *)barTintColor
{
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        self.appearance.backgroundColor = barTintColor;
        _tabController.tabBar.standardAppearance = self.appearance;
    } else {
        _tabController.tabBar.barTintColor = barTintColor;
    }
}

- (UIColor *)tintColor
{
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        return _tabController.tabBar.standardAppearance.selectionIndicatorTintColor;
    } else {
        return _tabController.tabBar.tintColor;
    }
}

- (void)setTintColor:(UIColor *)tintColor
{
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        self.appearance.selectionIndicatorTintColor = tintColor;
        _tabController.tabBar.standardAppearance = self.appearance;
         [self.reactSubviews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger index, __unused BOOL *stop) {
             RCTTabBarItem *tab = (RCTTabBarItem *)view;

              [tab.barItem setTitleTextAttributes:@{NSForegroundColorAttributeName: self.tintColor} forState:UIControlStateSelected];
         }];
    } else {
        _tabController.tabBar.tintColor = tintColor;
    }
    
}

- (BOOL)translucent
{
    return _tabController.tabBar.isTranslucent;
}

- (void)setTranslucent:(BOOL)translucent
{
    [_tabController.tabBar setTranslucent:translucent];
}

#if !TARGET_OS_TV
- (UIBarStyle)barStyle
{
  return _tabController.tabBar.barStyle;
}

- (void)setBarStyle:(UIBarStyle)barStyle
{
  _tabController.tabBar.barStyle = barStyle;
}
#endif

- (void)setUnselectedItemTintColor:(UIColor *)unselectedItemTintColor {
#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
  if ([_tabController.tabBar respondsToSelector:@selector(unselectedItemTintColor)]) {
    _tabController.tabBar.unselectedItemTintColor = unselectedItemTintColor;
  }
#endif
}

- (UITabBarItemPositioning)itemPositioning
{
#if TARGET_OS_TV
  return 0;
#else
  return _tabController.tabBar.itemPositioning;
#endif
}

- (void)setItemPositioning:(UITabBarItemPositioning)itemPositioning
{
#if !TARGET_OS_TV
  _tabController.tabBar.itemPositioning = itemPositioning;
#endif
}

#pragma mark - UITabBarControllerDelegate

#if TARGET_OS_TV

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(nonnull UIViewController *)viewController
{
  NSUInteger index = [tabBarController.viewControllers indexOfObject:viewController];
  RCTTabBarItem *tab = (RCTTabBarItem *)self.reactSubviews[index];
  if (tab.onPress) tab.onPress(nil);
  return;
}

#else

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController
{
  NSUInteger index = [tabBarController.viewControllers indexOfObject:viewController];
  RCTTabBarItem *tab = (RCTTabBarItem *)self.reactSubviews[index];
  if (tab.onPress) tab.onPress(nil);
  return NO;
}

#endif

#if TARGET_OS_TV

- (BOOL)isUserInteractionEnabled
{
  return YES;
}

/*
- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator
{
  if (context.nextFocusedView == self) {
    [self becomeFirstResponder];
  } else {
    [self resignFirstResponder];
  }
}
 */

#if defined(__TV_OS_VERSION_MAX_ALLOWED) && defined(__TVOS_13_0) && __TV_OS_VERSION_MAX_ALLOWED >= __TVOS_13_0
- (id<UIViewControllerAnimatedTransitioning>)tabBarController:(UITabBarController *)tabBarController animationControllerForTransitionFromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    TransitionAnimator *animator = [[TransitionAnimator alloc] init];
    return animator;
}
#endif

#endif

@end
