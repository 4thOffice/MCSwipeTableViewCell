//
//  MCSwipeTableViewCell.m
//  MCSwipeTableViewCell
//
//  Created by Ali Karagoz on 24/02/13.
//  Copyright (c) 2014 Ali Karagoz. All rights reserved.
//

#import "MCSwipeTableViewCell.h"

static CGFloat const kMCStop1                       = 0.25; // Percentage limit to trigger the first action
static CGFloat const kMCStop2                       = 0.75; // Percentage limit to trigger the second action
static CGFloat const kMCBounceAmplitude             = 20.0; // Maximum bounce amplitude when using the MCSwipeTableViewCellModeSwitch mode
static CGFloat const kMCDamping                     = 0.6;  // Damping of the spring animation
static CGFloat const kMCVelocity                    = 0.9;  // Velocity of the spring animation
static CGFloat const kMCAnimationDuration           = 0.4;  // Duration of the animation
static NSTimeInterval const kMCBounceDuration1      = 0.2;  // Duration of the first part of the bounce animation
static NSTimeInterval const kMCBounceDuration2      = 0.1;  // Duration of the second part of the bounce animation
static NSTimeInterval const kMCDurationLowLimit     = 0.25; // Lowest duration when swiping the cell because we try to simulate velocity
static NSTimeInterval const kMCDurationHighLimit    = 0.1;  // Highest duration when swiping the cell because we try to simulate velocity

typedef NS_ENUM(NSUInteger, MCSwipeTableViewCellDirection) {
    MCSwipeTableViewCellDirectionLeft = 0,
    MCSwipeTableViewCellDirectionCenter,
    MCSwipeTableViewCellDirectionRight
};

@interface MCSwipeTableViewCell () <UIGestureRecognizerDelegate>

@property (nonatomic, assign) MCSwipeTableViewCellDirection direction;
@property (nonatomic, assign) CGFloat currentPercentage;
@property (nonatomic, assign) BOOL isExited;

@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic, strong) UIImageView *contentScreenshotView;
@property (nonatomic, strong) UIView *colorIndicatorView;
@property (nonatomic, strong) UIView *slidingView;
@property (nonatomic, strong) UIView *activeView;

@property (nonatomic, strong) UIView *tempHolderView;
@property (nonatomic, strong) UIColor *tempHolderColor;


// Initialization
- (void)initializer;
- (void)initDefaults;

// View Manipulation.
- (void)setupSwipingView;
- (void)uninstallSwipingView;
- (void)setViewOfSlidingView:(UIView *)slidingView;

// Percentage
- (CGFloat)offsetWithPercentage:(CGFloat)percentage relativeToWidth:(CGFloat)width;
- (CGFloat)percentageWithOffset:(CGFloat)offset relativeToWidth:(CGFloat)width;
- (NSTimeInterval)animationDurationWithVelocity:(CGPoint)velocity;
- (MCSwipeTableViewCellDirection)directionWithPercentage:(CGFloat)percentage;
- (UIView *)viewWithPercentage:(CGFloat)percentage;
- (CGFloat)alphaWithPercentage:(CGFloat)percentage;
- (UIColor *)colorWithPercentage:(CGFloat)percentage;
- (MCSwipeTableViewCellState)stateWithPercentage:(CGFloat)percentage;

// Movement
- (void)animateWithOffset:(CGFloat)offset;
- (void)slideViewWithPercentage:(CGFloat)percentage view:(UIView *)view isDragging:(BOOL)isDragging;
- (void)moveWithDuration:(NSTimeInterval)duration andDirection:(MCSwipeTableViewCellDirection)direction;

// Utilities
- (UIImage *)imageWithView:(UIView *)view;

// Completion block.
- (void)executeCompletionBlock;

@end

@implementation MCSwipeTableViewCell

#pragma mark - Initialization

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self initializer];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initializer];
    }
    return self;
}

- (id)init {
    self = [super init];
    if (self) {
        [self initializer];
    }
    return self;
}

- (void)initializer {
    
    [self initDefaults];
    
    // Setup Gesture Recognizer.
    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGestureRecognizer:)];
    [self addGestureRecognizer:_panGestureRecognizer];
    _panGestureRecognizer.delegate = self;
}

- (void)initDefaults {
    
    _isExited = NO;
    _dragging = NO;
    _shouldDrag = YES;
    _shouldAnimateIcons = YES;
    
    _firstTrigger = kMCStop1;
    _secondTrigger = kMCStop2;
    
    _damping = kMCDamping;
    _velocity = kMCVelocity;
    _animationDuration = kMCAnimationDuration;
    
    _defaultColor = [UIColor whiteColor];
    
    _modeForState1 = MCSwipeTableViewCellModeNone;
    _modeForState2 = MCSwipeTableViewCellModeNone;
    _modeForState3 = MCSwipeTableViewCellModeNone;
    _modeForState4 = MCSwipeTableViewCellModeNone;
    
    _color1 = nil;
    _color2 = nil;
    _color3 = nil;
    _color4 = nil;
    
    _activeView = nil;
    _view1 = nil;
    _view2 = nil;
    _view3 = nil;
    _view4 = nil;
}

#pragma mark - Prepare reuse

- (void)prepareForReuse {
    [super prepareForReuse];
    
    [self uninstallSwipingView];
    [self initDefaults];
}

#pragma mark - View Manipulation

- (void)setupSwipingView {
    if (_contentScreenshotView) {
        return;
    }
    
    // If the content view background is transparent we get the background color.
    BOOL isContentViewBackgroundClear = !self.contentView.backgroundColor;
    if (isContentViewBackgroundClear) {
        BOOL isBackgroundClear = [self.backgroundColor isEqual:[UIColor clearColor]];
        self.contentView.backgroundColor = isBackgroundClear ? [UIColor whiteColor] :self.backgroundColor;
    }
    
    UIImage *contentViewScreenshotImage = [self imageWithView:self];
    
    if (isContentViewBackgroundClear) {
        self.contentView.backgroundColor = nil;
    }
    
    _colorIndicatorView = [[UIView alloc] initWithFrame:self.bounds];
    _colorIndicatorView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
    _colorIndicatorView.backgroundColor = self.defaultColor ? self.defaultColor : [UIColor clearColor];
    [self addSubview:_colorIndicatorView];
    
    _slidingView = [[UIView alloc] init];
    _slidingView.contentMode = UIViewContentModeCenter;
    [_colorIndicatorView addSubview:_slidingView];
    
    _contentScreenshotView = [[UIImageView alloc] initWithImage:contentViewScreenshotImage];
    [self addSubview:_contentScreenshotView];
}

- (void)uninstallSwipingView {
    if (!_contentScreenshotView) {
        return;
    }
    
    [_slidingView removeFromSuperview];
    _slidingView = nil;
    
    [_colorIndicatorView removeFromSuperview];
    _colorIndicatorView = nil;
    
    [_contentScreenshotView removeFromSuperview];
    _contentScreenshotView = nil;
}

- (void)setViewOfSlidingView:(UIView *)slidingView {
    if (!_slidingView) {
        return;
    }
    
    NSArray *subviews = [_slidingView subviews];
    [subviews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        [view removeFromSuperview];
    }];
    
    [_slidingView addSubview:slidingView];
}

#pragma mark - Swipe configuration

- (void)setSwipeGestureWithView:(UIView *)view
                          color:(UIColor *)color
                           mode:(MCSwipeTableViewCellMode)mode
                          state:(MCSwipeTableViewCellState)state
                completionBlock:(MCSwipeCompletionBlock)completionBlock {
    
    NSParameterAssert(view);
    NSParameterAssert(color);
    
    // Depending on the state we assign the attributes
    if ((state & MCSwipeTableViewCellState1) == MCSwipeTableViewCellState1) {
        _completionBlock1 = completionBlock;
        _view1 = view;
        _color1 = color;
        _modeForState1 = mode;
    }
    
    if ((state & MCSwipeTableViewCellState2) == MCSwipeTableViewCellState2) {
        _completionBlock2 = completionBlock;
        _view2 = view;
        _color2 = color;
        _modeForState2 = mode;
    }
    
    if ((state & MCSwipeTableViewCellState3) == MCSwipeTableViewCellState3) {
        _completionBlock3 = completionBlock;
        _view3 = view;
        _color3 = color;
        _modeForState3 = mode;
    }
    
    if ((state & MCSwipeTableViewCellState4) == MCSwipeTableViewCellState4) {
        _completionBlock4 = completionBlock;
        _view4 = view;
        _color4 = color;
        _modeForState4 = mode;
    }
}

#pragma mark - Handle Gestures

- (void)handlePanGestureRecognizer:(UIPanGestureRecognizer *)gesture {
    
    if (!_shouldDrag || _isExited) {
        return;
    }
    
    UIGestureRecognizerState state      = [gesture state];
    CGPoint translation                 = [gesture translationInView:self];
    CGPoint velocity                    = [gesture velocityInView:self];
    CGFloat percentage                  = [self percentageWithOffset:CGRectGetMinX(_contentScreenshotView.frame) relativeToWidth:CGRectGetWidth(self.bounds)];
    NSTimeInterval animationDuration    = [self animationDurationWithVelocity:velocity];
    _direction                          = [self directionWithPercentage:percentage];
    
    if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) {
        [self animateSliderWithXTranslation:translation.x
                     swipeAnimationDuration:0.0f
                                  withDelay:0.0f
                    endingAnimationDuration:animationDuration
                                   hasEnded:NO
                        ignoreSwipeProgress:NO
                                 completion:NULL];
        [gesture setTranslation:CGPointZero inView:self];
    } else if (state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled) {
        [self animateSliderWithXTranslation:translation.x
                     swipeAnimationDuration:0.0f
                                  withDelay:0.0f
                    endingAnimationDuration:animationDuration
                                   hasEnded:YES
                        ignoreSwipeProgress:YES
                                 completion:NULL];
    }
}

- (void)animateSliderWithXTranslation:(CGFloat)xTranslation swipeAnimationDuration:(NSTimeInterval)swipeAnimationDuration withDelay:(NSTimeInterval)withDelay endingAnimationDuration:(CGFloat)endingAnimationDuration hasEnded:(BOOL)hasEnded ignoreSwipeProgress:(BOOL)ignoreSwipe completion:(void (^ __nullable)(BOOL finished))completion {
    CGFloat percentage = [self percentageWithOffset:CGRectGetMinX(_contentScreenshotView.frame) relativeToWidth:CGRectGetWidth(self.bounds)];
    
    if (!hasEnded) {
        _dragging = YES;
        
        [self setupSwipingView];
        
        [UIView animateWithDuration:swipeAnimationDuration
                              delay:withDelay
                            options:kNilOptions
                         animations:^{
                             CGPoint center = {_contentScreenshotView.center.x + xTranslation, _contentScreenshotView.center.y};
                             _contentScreenshotView.center = center;
                         }
                         completion:completion];
        
        [self animateWithOffset:CGRectGetMinX(_contentScreenshotView.frame)];
        
        // Notifying the delegate that we are dragging with an offset percentage.
        if (!ignoreSwipe) {
            if ([_delegate respondsToSelector:@selector(swipeTableViewCell:didSwipeWithPercentage:)]) {
                [_delegate swipeTableViewCell:self didSwipeWithPercentage:percentage];
            }
        }
    } else {
        _dragging = NO;
        _activeView = [self viewWithPercentage:percentage];
        _currentPercentage = percentage;
        
        MCSwipeTableViewCellState cellState = [self stateWithPercentage:percentage];
        MCSwipeTableViewCellMode cellMode = MCSwipeTableViewCellModeNone;
        
        if (cellState == MCSwipeTableViewCellState1 && _modeForState1) {
            cellMode = self.modeForState1;
        }
        
        else if (cellState == MCSwipeTableViewCellState2 && _modeForState2) {
            cellMode = self.modeForState2;
        }
        
        else if (cellState == MCSwipeTableViewCellState3 && _modeForState3) {
            cellMode = self.modeForState3;
        }
        
        else if (cellState == MCSwipeTableViewCellState4 && _modeForState4) {
            cellMode = self.modeForState4;
        }
        
        if (cellMode == MCSwipeTableViewCellModeExit && _direction != MCSwipeTableViewCellDirectionCenter) {
            [self moveWithDuration:endingAnimationDuration andDirection:_direction];
        }
        
        else {
            [self swipeToOriginWithDelay:withDelay duration:endingAnimationDuration completion:^{
                if (!ignoreSwipe) {
                    [self executeCompletionBlock];
                }
                
                if (completion) {
                    completion(YES);
                }
            }];
        }
        
        // We notify the delegate that we just ended swiping.
        if (!ignoreSwipe) {
            if ([_delegate respondsToSelector:@selector(swipeTableViewCellDidEndSwiping:)]) {
                [_delegate swipeTableViewCellDidEndSwiping:self];
            }
        }
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    
    if ([gestureRecognizer class] == [UIPanGestureRecognizer class]) {
        
        UIPanGestureRecognizer *g = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint point = [g velocityInView:self];
        
        if (fabsf(point.x) > fabsf(point.y) ) {
            if (point.x < 0 && !_modeForState3 && !_modeForState4) {
                return NO;
            }
            
            if (point.x > 0 && !_modeForState1 && !_modeForState2) {
                return NO;
            }
            
            // We notify the delegate that we just started dragging
            if ([_delegate respondsToSelector:@selector(swipeTableViewCellDidStartSwiping:)]) {
                [_delegate swipeTableViewCellDidStartSwiping:self];
            }
            
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - Percentage

- (CGFloat)offsetWithPercentage:(CGFloat)percentage relativeToWidth:(CGFloat)width {
    CGFloat offset = percentage * width;
    
    if (offset < -width) offset = -width;
    else if (offset > width) offset = width;
    
    return offset;
}

- (CGFloat)percentageWithOffset:(CGFloat)offset relativeToWidth:(CGFloat)width {
    CGFloat percentage = offset / width;
    
    if (percentage < -1.0) percentage = -1.0;
    else if (percentage > 1.0) percentage = 1.0;
    
    return percentage;
}

- (NSTimeInterval)animationDurationWithVelocity:(CGPoint)velocity {
    CGFloat width                           = CGRectGetWidth(self.bounds);
    NSTimeInterval animationDurationDiff    = kMCDurationHighLimit - kMCDurationLowLimit;
    CGFloat horizontalVelocity              = velocity.x;
    
    if (horizontalVelocity < -width) horizontalVelocity = -width;
    else if (horizontalVelocity > width) horizontalVelocity = width;
    
    return (kMCDurationHighLimit + kMCDurationLowLimit) - fabs(((horizontalVelocity / width) * animationDurationDiff));
}

- (MCSwipeTableViewCellDirection)directionWithPercentage:(CGFloat)percentage {
    if (percentage < 0) {
        return MCSwipeTableViewCellDirectionLeft;
    }
    
    else if (percentage > 0) {
        return MCSwipeTableViewCellDirectionRight;
    }
    
    else {
        return MCSwipeTableViewCellDirectionCenter;
    }
}

- (UIView *)viewWithPercentage:(CGFloat)percentage {
    
    UIView *view;
    
    if (percentage >= 0 && _modeForState1) {
        view = _view1;
    }
    
    if (percentage >= _secondTrigger && _modeForState2) {
        view = _view2;
    }
    
    if (percentage < 0  && _modeForState3) {
        view = _view3;
    }
    
    if (percentage <= -_secondTrigger && _modeForState4) {
        view = _view4;
    }
    
    return view;
}

- (CGFloat)alphaWithPercentage:(CGFloat)percentage {
    CGFloat alpha;
    
    if (percentage >= 0 && percentage < kMCStop1) {
        alpha = percentage / kMCStop1;
    }
    
    else if (percentage < 0 && percentage > -kMCStop1) {
        alpha = fabsf(percentage / kMCStop1);
    }
    
    else {
        alpha = 1.0;
    }
    
    return alpha;
}

- (UIColor *)colorWithPercentage:(CGFloat)percentage {
    UIColor *color;
    
    // Background Color
    
    color = self.defaultColor ? self.defaultColor : [UIColor clearColor];
    
    if (percentage > 0 && _modeForState1) {
        color = _color1;
    }
    
    if (percentage > _secondTrigger && _modeForState2) {
        color = _color2;
    }
    
    if (percentage < 0 && _modeForState3) {
        color = _color3;
    }
    
    if (percentage <= -_secondTrigger && _modeForState4) {
        color = _color4;
    }
    
    return color;
}

- (MCSwipeTableViewCellState)stateWithPercentage:(CGFloat)percentage {
    MCSwipeTableViewCellState state;
    
    state = MCSwipeTableViewCellStateNone;
    
    if (percentage >= _firstTrigger && _modeForState1) {
        state = MCSwipeTableViewCellState1;
    }
    
    if (percentage >= _secondTrigger && _modeForState2) {
        state = MCSwipeTableViewCellState2;
    }
    
    if (percentage <= -_firstTrigger && _modeForState3) {
        state = MCSwipeTableViewCellState3;
    }
    
    if (percentage <= -_secondTrigger && _modeForState4) {
        state = MCSwipeTableViewCellState4;
    }
    
    return state;
}

#pragma mark - Movement

- (void)animateWithOffset:(CGFloat)offset {
    CGFloat percentage = [self percentageWithOffset:offset relativeToWidth:CGRectGetWidth(self.bounds)];
    
    UIView *view = [self viewWithPercentage:percentage];
    
    // View Position.
    if (view) {
        [self setViewOfSlidingView:view];
        _slidingView.alpha = [self alphaWithPercentage:percentage];
        
        [self slideViewWithPercentage:percentage view:view isDragging:self.shouldAnimateIcons];
    }
    
    // Color
    UIColor *color = [self colorWithPercentage:percentage];
    if (color != nil) {
        _colorIndicatorView.backgroundColor = color;
    }
}

- (void)slideViewWithPercentage:(CGFloat)percentage view:(UIView *)view isDragging:(BOOL)isDragging {
    if (!view) {
        return;
    }
    
    CGPoint position = CGPointZero;
    position.y = CGRectGetHeight(self.bounds) / 2.0;
    
    if (isDragging) {
        if (percentage >= 0 && percentage < kMCStop1) {
            position.x = [self offsetWithPercentage:(kMCStop1 / 2) relativeToWidth:CGRectGetWidth(self.bounds)];
        }
        
        else if (percentage >= kMCStop1) {
            position.x = [self offsetWithPercentage:percentage - (kMCStop1 / 2) relativeToWidth:CGRectGetWidth(self.bounds)];
        }
        
        else if (percentage < 0 && percentage >= -kMCStop1) {
            position.x = CGRectGetWidth(self.bounds) - [self offsetWithPercentage:(kMCStop1 / 2) relativeToWidth:CGRectGetWidth(self.bounds)];
        }
        
        else if (percentage < -kMCStop1) {
            position.x = CGRectGetWidth(self.bounds) + [self offsetWithPercentage:percentage + (kMCStop1 / 2) relativeToWidth:CGRectGetWidth(self.bounds)];
        }
    }
    
    else {
        if (_direction == MCSwipeTableViewCellDirectionRight) {
            position.x = [self offsetWithPercentage:(kMCStop1 / 2) relativeToWidth:CGRectGetWidth(self.bounds)];
        }
        
        else if (_direction == MCSwipeTableViewCellDirectionLeft) {
            position.x = CGRectGetWidth(self.bounds) - [self offsetWithPercentage:(kMCStop1 / 2) relativeToWidth:CGRectGetWidth(self.bounds)];
        }
        
        else {
            return;
        }
    }
    
    CGSize activeViewSize = view.bounds.size;
    CGRect activeViewFrame = CGRectMake(position.x - activeViewSize.width / 2.0,
                                        position.y - activeViewSize.height / 2.0,
                                        activeViewSize.width,
                                        activeViewSize.height);
    
    activeViewFrame = CGRectIntegral(activeViewFrame);
    _slidingView.frame = activeViewFrame;
}

- (void)moveWithDuration:(NSTimeInterval)duration andDirection:(MCSwipeTableViewCellDirection)direction {
    
    _isExited = YES;
    CGFloat origin;
    
    if (direction == MCSwipeTableViewCellDirectionLeft) {
        origin = -CGRectGetWidth(self.bounds);
    }
    
    else if (direction == MCSwipeTableViewCellDirectionRight) {
        origin = CGRectGetWidth(self.bounds);
    }
    
    else {
        origin = 0;
    }
    
    CGFloat percentage = [self percentageWithOffset:origin relativeToWidth:CGRectGetWidth(self.bounds)];
    CGRect frame = _contentScreenshotView.frame;
    frame.origin.x = origin;
    
    // Color
    UIColor *color = [self colorWithPercentage:_currentPercentage];
    if (color) {
        [_colorIndicatorView setBackgroundColor:color];
    }
    
    [UIView animateWithDuration:duration delay:0 options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction) animations:^{
        _contentScreenshotView.frame = frame;
        _slidingView.alpha = 0;
        [self slideViewWithPercentage:percentage view:_activeView isDragging:self.shouldAnimateIcons];
    } completion:^(BOOL finished) {
        [self executeCompletionBlock];
    }];
}

- (void)swipeToOriginWithCompletion:(void(^)(void))completion {
    [self swipeToOriginWithDelay:0.f
                        duration:kMCBounceDuration1
                      completion:completion];
}

- (void)swipeToOriginWithDelay:(NSTimeInterval)delay duration:(NSTimeInterval)duration completion:(void(^)(void))completion {
    CGFloat bounceDistance = kMCBounceAmplitude * _currentPercentage;
    
    [UIView animateWithDuration:duration delay:delay options:(UIViewAnimationOptionCurveEaseOut) animations:^{
        
        CGRect frame = _contentScreenshotView.frame;
        frame.origin.x = -bounceDistance;
        _contentScreenshotView.frame = frame;
        
        _slidingView.alpha = 0;
        [self slideViewWithPercentage:0 view:_activeView isDragging:NO];
        
        // Setting back the color to the default.
        _colorIndicatorView.backgroundColor = self.defaultColor;
        
    } completion:^(BOOL finished1) {
        
        [UIView animateWithDuration:kMCBounceDuration2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            
            CGRect frame = _contentScreenshotView.frame;
            frame.origin.x = 0;
            _contentScreenshotView.frame = frame;
            
            // Clearing the indicator view
            _colorIndicatorView.backgroundColor = [UIColor clearColor];
            
        } completion:^(BOOL finished2) {
            
            _isExited = NO;
            [self uninstallSwipingView];
            
            if (completion) {
                completion();
            }
        }];
    }];
}

#pragma mark - Trigger Manually

- (void)performManualSwipeAnimation:(UIView * _Nullable)view
                              color:(UIColor *)color
                              state:(MCSwipeTableViewCellState)state
                       xTranslation:(CGFloat)xTranslation
                         completion:(void (^ __nullable)(BOOL finished))completion {
    _firstTrigger = 1.0;
    _secondTrigger = 1.0;
    
    // Use a mock percentage to determine the right swipe direction.
    CGFloat mockPercentage = (xTranslation > 0) ? 0.01 : -0.01;
    _direction = [self directionWithPercentage:mockPercentage];
    
    _shouldAnimateIcons = false;
    
    switch (state) {
        case MCSwipeTableViewCellState1: {
            _tempHolderView = _view1;
            _tempHolderColor = _color1;
            
            _view1 = view;
            _color1 = color;
        } break;
        case MCSwipeTableViewCellState2: {
            _tempHolderView = _view2;
            _tempHolderColor = _color2;
            
            _view2 = view;
            _color2 = color;
        } break;
        case MCSwipeTableViewCellState3: {
            _tempHolderView = _view3;
            _tempHolderColor = _color3;
            
            _view3 = view;
            _color3 = color;
        } break;
        case MCSwipeTableViewCellState4: {
            _tempHolderView = _view4;
            _tempHolderColor = _color4;
            
            _view4 = view;
            _color4 = color;
        } break;
        default:
            break;
    }
    
    [self animateSliderWithXTranslation:xTranslation
                 swipeAnimationDuration:0.3f
                              withDelay:0.0f
                endingAnimationDuration:0.3f
                               hasEnded:NO
                    ignoreSwipeProgress:YES
                             completion:^(BOOL finished) {
                                 _firstTrigger = kMCStop1;
                                 _secondTrigger = kMCStop2;
                                 
                                 // set the intial view back
                                 switch (state) {
                                     case MCSwipeTableViewCellState1: {
                                         _view1 = _tempHolderView;
                                         _color1 = _tempHolderColor;
                                     } break;
                                     case MCSwipeTableViewCellState2: {
                                         _view2 = _tempHolderView;
                                         _color2 = _tempHolderColor;
                                     } break;
                                     case MCSwipeTableViewCellState3: {
                                         _view3= _tempHolderView;
                                         _color3 = _tempHolderColor;
                                     } break;
                                     case MCSwipeTableViewCellState4: {
                                         _view4 = _tempHolderView;
                                         _color4 = _tempHolderColor;
                                     } break;
                                     default:
                                         break;
                                 }
                                 
                                 if (completion) {
                                     completion(YES);
                                 }
                             }];
}

- (void)performManualBounceAnimation:(CGFloat)xTranslation
                          completion:(void (^ __nullable)(BOOL finished))completion {
    _firstTrigger = 1.0;
    _secondTrigger = 1.0;
    
    _shouldAnimateIcons = false;
    
    // Use a mock percentage to determine the right swipe direction.
    CGFloat mockPercentage = (xTranslation > 0) ? 0.01 : -0.01;
    _direction = [self directionWithPercentage:mockPercentage];
    
    [self animateSliderWithXTranslation:xTranslation
                 swipeAnimationDuration:0.5f
                              withDelay:0.0f
                endingAnimationDuration:0.f
                               hasEnded:NO
                    ignoreSwipeProgress:YES
                             completion:^(BOOL finished) {
                                 [self animateSliderWithXTranslation:0.f
                                              swipeAnimationDuration:0.f
                                                           withDelay:0.5f
                                             endingAnimationDuration:0.5f
                                                            hasEnded:YES
                                                 ignoreSwipeProgress:YES
                                                          completion:^(BOOL finished) {
                                                              _firstTrigger = kMCStop1;
                                                              _secondTrigger = kMCStop2;
                                                              
                                                              if (completion) {
                                                                  completion(YES);
                                                              }
                                                          }];
                             }];
}

- (void)performManualLeftAnimation:(UIView * _Nullable)view color:(UIColor *)color state:(MCSwipeTableViewCellState)state completion:(void (^ __nullable)(BOOL finished))completion {
    [self performManualSwipeAnimation:view color:color state:state xTranslation:self.frame.size.width completion:completion];
}

- (void)performManualRightAnimation:(UIView * _Nullable)view color:(UIColor *)color state:(MCSwipeTableViewCellState)state completion:(void (^ __nullable)(BOOL finished))completion {
    [self performManualSwipeAnimation:view color:color state:state xTranslation:-self.frame.size.width completion:completion];
}

#pragma mark - Utilities

- (UIImage *)imageWithView:(UIView *)view {
    CGFloat scale = [[UIScreen mainScreen] scale];
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, scale);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage * image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

#pragma mark - Completion block

- (void)executeCompletionBlock {
    MCSwipeTableViewCellState state = [self stateWithPercentage:_currentPercentage];
    MCSwipeTableViewCellMode mode = MCSwipeTableViewCellModeNone;
    MCSwipeCompletionBlock completionBlock;
    
    switch (state) {
        case MCSwipeTableViewCellState1: {
            mode = self.modeForState1;
            completionBlock = _completionBlock1;
        } break;
            
        case MCSwipeTableViewCellState2: {
            mode = self.modeForState2;
            completionBlock = _completionBlock2;
        } break;
            
        case MCSwipeTableViewCellState3: {
            mode = self.modeForState3;
            completionBlock = _completionBlock3;
        } break;
            
        case MCSwipeTableViewCellState4: {
            mode = self.modeForState4;
            completionBlock = _completionBlock4;
        } break;
            
        default:
            break;
    }
    
    if (completionBlock) {
        completionBlock(self, state, mode);
    }
    
}

@end

