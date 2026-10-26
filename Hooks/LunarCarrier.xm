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

// 用 NSUserDefaults suiteName 读设置（PreferenceLoader 写入的域）
static NSUserDefaults *prefs() {
    static NSUserDefaults *d = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        d = [[NSUserDefaults alloc] initWithSuiteName:kDomain];
        [d synchronize];
    });
    return d;
}

static id prefGet(NSString *key) {
    return [prefs() objectForKey:key];
}

static BOOL prefBool(NSString *key, BOOL def) {
    id v = prefGet(key);
    if (v == nil) return def;
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
    // 年开关：关闭则去掉到"年"为止
    if (!prefBool(@"ShowYear", YES)) {
        NSRange yr = [input rangeOfString:@"年"];
        if (yr.location != NSNotFound) {
            input = [input substringFromIndex:yr.location + 1];
        }
    }
    // 统一替换（|| 分隔多组）
    return applyPairs(input, prefStr(@"Find"), prefStr(@"Replace"));
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

// 只替换状态栏里的 carrier label（superview 链含 _UIStatusBar）
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
    if (isCarrierText(text) && isInStatusBar(self) && shouldReplace()) {
        text = lunarText();
        dispatch_async(dispatch_get_main_queue(), ^{ applyStyle(self); });
    }
    %orig;
}
- (void)setAttributedText:(NSAttributedString *)text {
    if (isCarrierText(text.string) && isInStatusBar(self) && shouldReplace()) {
        text = [[NSAttributedString alloc] initWithString:lunarText()];
        dispatch_async(dispatch_get_main_queue(), ^{ applyStyle(self); });
    }
    %orig;
}
%end

%ctor {
    writeLog([NSString stringWithFormat:@"v19 锁屏=%d 任务栏=%d Find1=[%@] Replace1=[%@]",
              prefBool(@"LockEnabled", YES), prefBool(@"SpringboardEnabled", YES),
              prefStr(@"Find1"), prefStr(@"Replace1")]);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                     NULL, onLockStateChanged,
                                     CFSTR("com.apple.springboard.lockcomplete"),
                                     NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                     NULL, onLockStateChanged,
                                     CFSTR("com.apple.springboard.unlockcomplete"),
                                     NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
