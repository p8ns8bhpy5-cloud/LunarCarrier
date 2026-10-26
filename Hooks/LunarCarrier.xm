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

// 农历字符串：去掉"X年"，月名替换，加粗
static NSAttributedString *lunarAttributed(UIFont *baseFont) {
    NSString *s = lunarDateString();
    NSRange yr = [s rangeOfString:@"年"];
    if (yr.location != NSNotFound) {
        s = [s substringFromIndex:yr.location + 1];
    }
    NSDictionary *map = @{@"十一月":@"冬月", @"十二月":@"腊月"};
    for (NSString *k in map) {
        s = [s stringByReplacingOccurrencesOfString:k withString:map[k]];
    }
    UIFont *f = baseFont ?: [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    UIFont *boldF = [UIFont fontWithDescriptor:[[f fontDescriptor] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold] size:f.pointSize];
    return [[NSAttributedString alloc] initWithString:s attributes:@{NSFontAttributeName: boldF}];
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

// 只替换主卡（上方那行）：label 在状态栏内 y 坐标较小的
static BOOL isMainCarrierLabel(UILabel *label) {
    // 取 label 在其 superview 里的 y
    CGFloat y = label.frame.origin.y;
    // 主卡通常在上方，y 较小（0~10）；副卡 y 较大（>10）
    return y < 10;
}

%hook UILabel
- (void)setText:(NSString *)text {
    if (gIsLocked && isCarrierText(text) && isInStatusBar(self) && isMainCarrierLabel(self)) {
        NSAttributedString *a = lunarAttributed(self.font);
        text = a.string;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setAttributedText:lunarAttributed(self.font)];
        });
    }
    %orig;
}
- (void)setAttributedText:(NSAttributedString *)text {
    if (gIsLocked && isCarrierText(text.string) && isInStatusBar(self) && isMainCarrierLabel(self)) {
        text = lunarAttributed(self.font);
    }
    %orig;
}
%end

%ctor {
    writeLog(@"LunarCarrier v34 只显示月日加粗");
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                     NULL, onLockStateChanged,
                                     CFSTR("com.apple.springboard.lockcomplete"),
                                     NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                     NULL, onLockStateChanged,
                                     CFSTR("com.apple.springboard.unlockcomplete"),
                                     NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
