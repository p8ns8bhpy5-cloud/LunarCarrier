#import "lunar.h"
#import <UIKit/UIKit.h>
#import <substrate.h>

static void writeLog(NSString *msg) {
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], msg];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    NSString *p = @"/var/mobile/LunarCarrier.log";
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:p];
    if (fh) { [fh seekToEndOfFile]; [fh writeData:data]; }
    else { [data writeToFile:p atomically:YES]; }
}

static BOOL gIsLocked = NO;

static void onLockStateChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSString *n = (__bridge NSString *)name;
    if ([n isEqualToString:@"com.apple.springboard.lockcomplete"]) gIsLocked = YES;
    else if ([n isEqualToString:@"com.apple.springboard.unlockcomplete"]) gIsLocked = NO;
}

static NSString *lunarText(void) {
    NSString *s = lunarDateString();  // "马年九月十七"
    // 取生肖字（第一个字）
    NSString *zodiac = @"";
    NSRange yr = [s rangeOfString:@"年"];
    if (yr.location != NSNotFound) {
        zodiac = [s substringToIndex:1];  // "马"
        s = [s substringFromIndex:yr.location + 1];  // "九月十七"
    }
    // 月名替换
    NSDictionary *map = @{@"十一月":@"冬月", @"十二月":@"腊月"};
    for (NSString *k in map) {
        s = [s stringByReplacingOccurrencesOfString:k withString:map[k]];
    }
    if (zodiac.length) {
        s = [NSString stringWithFormat:@"%@ %@", zodiac, s];
    }
    return s;
}

static BOOL isCarrierText(NSString *s) {
    if (!s.length) return NO;
    NSArray *keys = @[@"移动", @"联通", @"电信", @"全球通", @"CMCC", @"China Mobile",
                      @"China Unicom", @"China Telecom"];
    for (NSString *k in keys) if ([s containsString:k]) return YES;
    return NO;
}

static BOOL isInStatusBar(UIView *v) {
    UIView *p = v;
    while (p) {
        NSString *cn = NSStringFromClass([p class]);
        if ([cn containsString:@"StatusBar"] || [cn containsString:@"statusBar"]) return YES;
        p = p.superview;
    }
    return NO;
}

%hook UILabel
- (void)setText:(NSString *)text {
    if (gIsLocked && isCarrierText(text) && isInStatusBar(self)) {
        text = lunarText();
    }
    %orig;
}
- (void)setAttributedText:(NSAttributedString *)text {
    if (gIsLocked && isCarrierText(text.string) && isInStatusBar(self)) {
        text = [[NSAttributedString alloc] initWithString:lunarText()];
    }
    %orig;
}
%end

%ctor {
    writeLog(@"LunarCarrier v29 只锁屏显示");
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                     NULL, onLockStateChanged,
                                     CFSTR("com.apple.springboard.lockcomplete"),
                                     NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                     NULL, onLockStateChanged,
                                     CFSTR("com.apple.springboard.unlockcomplete"),
                                     NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
