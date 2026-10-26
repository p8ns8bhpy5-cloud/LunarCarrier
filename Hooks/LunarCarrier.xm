#import "lunar.h"
#import <UIKit/UIKit.h>
#import <substrate.h>

static NSString *const kDomain = @"com.yourname.lunarcarrier";

static void writeLog(NSString *msg) {
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], msg];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    for (NSString *p in @[@"/var/mobile/LunarCarrier.log"]) {
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:p];
        if (fh) { [fh seekToEndOfFile]; [fh writeData:data]; }
        else { [data writeToFile:p atomically:YES]; }
    }
}

// 用 CFPreferences 读设置（rootless 兼容）
static id prefGet(NSString *key) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
    return (__bridge_transfer id)CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)kDomain);
}

static BOOL prefBool(NSString *key, BOOL def) {
    id v = prefGet(key);
    if (!v) return def;
    return [v boolValue];
}

static NSString *prefStr(NSString *key) {
    id v = prefGet(key);
    return [v isKindOfClass:[NSString class]] ? v : @"";
}

static BOOL gIsLocked = NO;

static void onLockStateChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSString *n = (__bridge NSString *)name;
    if ([n isEqualToString:@"com.apple.springboard.lockcomplete"]) gIsLocked = YES;
    else if ([n isEqualToString:@"com.apple.springboard.unlockcomplete"]) gIsLocked = NO;
}

// 对一段文字应用多组替换（用 || 分隔）
static NSString *applyPairs(NSString *text, NSString *find, NSString *repl) {
    if (!find.length) return text;
    NSArray *finds = [find componentsSeparatedByString:@"||"];
    NSArray *reps = repl.length ? [repl componentsSeparatedByString:@"||"] : @[];
    for (NSUInteger i = 0; i < finds.count; i++) {
        NSString *f = finds[i];
        if (!f.length) continue;
        NSString *r = i < reps.count ? reps[i] : @"";
        text = [text stringByReplacingOccurrencesOfString:f withString:r];
    }
    return text;
}

static NSString *applyReplacement(NSString *input) {
    // 找"年"字位置
    NSRange yearRange = [input rangeOfString:@"年"];
    NSString *yearPart = yearRange.location != NSNotFound ? [input substringToIndex:yearRange.location + 1] : @"";
    NSString *rest = yearRange.location != NSNotFound ? [input substringFromIndex:yearRange.location + 1] : input;

    NSString *dayPart = @"";
    NSString *monthPart = rest;
    if (rest.length >= 2) {
        dayPart = [rest substringFromIndex:rest.length - 2];
        monthPart = [rest substringToIndex:rest.length - 2];
    }

    if (prefBool(@"RemoveLeapChar", NO)) {
        monthPart = [monthPart stringByReplacingOccurrencesOfString:@"闰" withString:@""];
    }
    yearPart = applyPairs(yearPart, prefStr(@"Find1"), prefStr(@"Replace1"));
    monthPart = applyPairs(monthPart, prefStr(@"Find2"), prefStr(@"Replace2"));
    dayPart = applyPairs(dayPart, prefStr(@"Find3"), prefStr(@"Replace3"));

    return [NSString stringWithFormat:@"%@%@%@", yearPart, monthPart, dayPart];
}

static BOOL isCarrierText(NSString *s) {
    if (!s.length) return NO;
    NSArray *keys = @[@"移动", @"联通", @"电信", @"全球通", @"CMCC", @"China Mobile",
                      @"China Unicom", @"China Telecom"];
    for (NSString *k in keys) if ([s containsString:k]) return YES;
    return NO;
}

static NSString *lunarText(void) {
    return applyReplacement(lunarDateString());
}

// 是否应该替换当前 carrier 文字（按开关 + 锁屏状态）
static BOOL shouldReplace(void) {
    if (gIsLocked) return prefBool(@"LockEnabled", YES);
    else return prefBool(@"SpringboardEnabled", YES);
}

// 替换后应用字体样式
static void applyStyle(UILabel *label) {
    NSString *colorHex = prefStr(@"TextColor");
    if (colorHex.length) {
        unsigned int rgb = 0;
        NSScanner *sc = [NSScanner scannerWithString:colorHex];
        [sc scanHexInt:&rgb];
        label.textColor = [UIColor colorWithRed:((rgb>>16)&0xFF)/255.0 green:((rgb>>8)&0xFF)/255.0 blue:(rgb&0xFF)/255.0 alpha:1.0];
    }
    CGFloat size = [prefStr(@"FontSize") doubleValue];
    NSString *weight = prefStr(@"FontWeight");
    UIFontWeight w = UIFontWeightRegular;
    if ([weight isEqualToString:@"thin"]) w = UIFontWeightThin;
    else if ([weight isEqualToString:@"light"]) w = UIFontWeightLight;
    else if ([weight isEqualToString:@"medium"]) w = UIFontWeightMedium;
    else if ([weight isEqualToString:@"bold"]) w = UIFontWeightBold;
    if (size <= 0) size = label.font.pointSize;
    label.font = [UIFont systemFontOfSize:size weight:w];
}

%hook UILabel
- (void)setText:(NSString *)text {
    if (isCarrierText(text) && shouldReplace()) {
        text = lunarText();
        [self setNeedsLayout];
        // 下一轮 runloop 应用样式
        dispatch_async(dispatch_get_main_queue(), ^{ applyStyle(self); });
    }
    %orig;
}
- (void)setAttributedText:(NSAttributedString *)text {
    if (isCarrierText(text.string) && shouldReplace()) {
        text = [[NSAttributedString alloc] initWithString:lunarText()];
        dispatch_async(dispatch_get_main_queue(), ^{ applyStyle(self); });
    }
    %orig;
}
%end

%ctor {
    writeLog(@"LunarCarrier 加载 (v17 CFPreferences+开关+样式)");
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                     NULL, onLockStateChanged,
                                     CFSTR("com.apple.springboard.lockcomplete"),
                                     NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                     NULL, onLockStateChanged,
                                     CFSTR("com.apple.springboard.unlockcomplete"),
                                     NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
