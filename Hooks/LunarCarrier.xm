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

// 返回 (生肖, 月日)
static NSArray *lunarParts(void) {
    NSString *s = lunarDateString();
    NSString *zodiac = @"";
    NSRange yr = [s rangeOfString:@"年"];
    if (yr.location != NSNotFound) {
        zodiac = [s substringToIndex:1];
        s = [s substringFromIndex:yr.location + 1];
    }
    NSDictionary *map = @{@"十一月":@"冬月", @"十二月":@"腊月"};
    for (NSString *k in map) {
        s = [s stringByReplacingOccurrencesOfString:k withString:map[k]];
    }
    return @[zodiac, s];
}

// 构造 attributed string：生肖加粗，其余正常
static NSAttributedString *lunarAttributed(UIFont *baseFont) {
    NSArray *parts = lunarParts();
    NSString *zodiac = parts[0];
    NSString *rest = parts[1];
    UIFont *boldFont = baseFont ?: [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    UIFont *normalFont = baseFont ?: [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    NSMutableAttributedString *mas = [[NSMutableAttributedString alloc] init];
    if (zodiac.length) {
        [mas appendAttributedString:[[NSAttributedString alloc] initWithString:zodiac attributes:@{NSFontAttributeName: boldFont}]];
    }
    [mas appendAttributedString:[[NSAttributedString alloc] initWithString:rest attributes:@{NSFontAttributeName: normalFont}]];
    return mas;
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
        NSArray *parts = lunarParts();
        text = [NSString stringWithFormat:@"%@%@", parts[0], parts[1]];
        // 下一轮设置 attributed string 让生肖加粗
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAttributedString *a = lunarAttributed(self.font);
            [self setAttributedText:a];
        });
    }
    %orig;
}
- (void)setAttributedText:(NSAttributedString *)text {
    if (gIsLocked && isCarrierText(text.string) && isInStatusBar(self)) {
        text = lunarAttributed(self.font);
    }
    %orig;
}
%end

%ctor {
    writeLog(@"LunarCarrier v33 生肖加粗");
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                     NULL, onLockStateChanged,
                                     CFSTR("com.apple.springboard.lockcomplete"),
                                     NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                     NULL, onLockStateChanged,
                                     CFSTR("com.apple.springboard.unlockcomplete"),
                                     NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
