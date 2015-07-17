//
//  SCMCMouseListener.m
//  Sculpt Control Inject Bundle
//
//  Created by Maxim Naumov on 11.07.15.
//  Copyright (c) 2015 Maxim Naumov. All rights reserved.
//

#import "SCMCMouseListener.h"

@import IOKit.hid;

typedef uint32_t ButtonCode;

typedef NS_ENUM(ButtonCode, ButtonCodeV1) {
    ButtonCodeV1Click = 64817,
    ButtonCodeV1SwipeUp = 64809,
    ButtonCodeV1SwipeDown = 64816,
};

typedef NS_ENUM(ButtonCode, ButtonCodeV2) {
    ButtonCodeV2Click = 227,
    ButtonCodeV2SwipeUp = 42,
    ButtonCodeV2SwipeDown = 43,
};

typedef NS_ENUM(NSInteger, LongClickState) {
    IdleLongClickState,
    DownLongClickState,
    WaitingReleaseLongClickState,
};

@interface SCMCMouseListener ()

@property(nonatomic, copy) void (^clickAction)();
@property(nonatomic, copy) void (^longClickAction)();
@property(nonatomic, copy) void (^swipeUpAction)();
@property(nonatomic, copy) void (^swipeDownAction)();

@end

static LongClickState ClickState;
static NSTimer *LongClickTimer;

static void HandleLongClick(__weak SCMCMouseListener *listener, BOOL down) {
    if (!down) { // button released
        [LongClickTimer invalidate];
        LongClickTimer = nil;

        if (ClickState == DownLongClickState) {
            listener.clickAction();
        }

        ClickState = IdleLongClickState;
    } else if (ClickState == IdleLongClickState) {
        LongClickTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
                target:[NSBlockOperation blockOperationWithBlock:^{
                    listener.longClickAction();
                    ClickState = WaitingReleaseLongClickState;
                }]
                selector:@selector(main)
                userInfo:nil
                repeats:NO
        ];
        ClickState = DownLongClickState;
    }
}

static void MouseCallback(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    SCMCMouseListener *listener = (__bridge SCMCMouseListener *) (context);
    long pressed = IOHIDValueGetIntegerValue(value);
    IOHIDElementRef elem = IOHIDValueGetElement(value);
    ButtonCode code = IOHIDElementGetUsage(elem);

    if (code == ButtonCodeV1Click || code == ButtonCodeV2Click) {
        HandleLongClick(listener, pressed == 1);
        return;
    }

    if (pressed != 1) return;

    switch (code) {
        case ButtonCodeV1SwipeUp:
        case ButtonCodeV2SwipeUp:
            listener.swipeUpAction();
            break;
        case ButtonCodeV1SwipeDown:
        case ButtonCodeV2SwipeDown:
            listener.swipeDownAction();
            break;
        default:
            return;
    }
}

@implementation SCMCMouseListener

- (instancetype)initWithClickAction:(void (^)())clickAction longClickAction:(void (^)())longClickAction swipeUpAction:(void (^)())swipeUpAction swipeDownAction:(void (^)())swipeDownAction {
    self = [super init];
    if (self) {
        self.clickAction = clickAction;
        self.longClickAction = longClickAction;
        self.swipeUpAction = swipeUpAction;
        self.swipeDownAction = swipeDownAction;
        [self setupListener];
    }

    return self;
}

+ (instancetype)listenerWithClickAction:(void (^)())clickAction longClickAction:(void (^)())longClickAction swipeUpAction:(void (^)())swipeUpAction swipeDownAction:(void (^)())swipeDownAction {
    return [[self alloc] initWithClickAction:clickAction longClickAction:longClickAction swipeUpAction:swipeUpAction swipeDownAction:swipeDownAction];
}

- (void)setupListener {
    IOHIDManagerRef hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    NSDictionary *sculptComfortMatch = @{
            @kIOHIDVendorIDKey : @0x45E,
            @kIOHIDProductIDKey : @0x7A2,
    };

    IOHIDManagerSetDeviceMatchingMultiple(hidManager, (__bridge CFArrayRef) @[sculptComfortMatch]);
    IOHIDManagerRegisterInputValueCallback(hidManager, MouseCallback, (__bridge void *) (self));
    IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    IOHIDManagerOpen(hidManager, kIOHIDOptionsTypeNone);
}

@end