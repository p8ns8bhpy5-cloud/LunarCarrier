#import "lunar.h"
#import <UIKit/UIKit.h>
#import <substrate.h>

static NSString *const kPrefsPath = @"/var/mobile/Library/Preferences/com.yourname.lunarcarrier.plist";

static void writeLog(NSString *msg) {
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], msg];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    for (NSString *p in @[@"/var/mobile/LunarCarrier.log"]) {
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:p];
        if (fh) { [fh seekToEndOfFile]; [fh writeData:data]; }
        else { [data writeToFile:p atomically:YES]; }
    }
}

// 读设置里的替换规则并应用到农历文字
static NSString *applyReplacement(NSString *input) {
    NSString *s = input;
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    if ([prefs[@"RemoveLeapChar"] boolValue])
        s = [s stringByReplacingOccurrencesOfString:@"闰" withString:@""];
    for (int i = 1; i <= 3; i++) {
        NSString *find = prefs[[NSString stringWithFormat:@"Find%d", i]];
        if (find.length) {
            NSString *repl = prefs[[NSString stringWithFormat:@"Replace%d", i]] ?: @"";
            s = [s stringByReplacingOccurrencesOfString:find withString:repl];
        }
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

static NSString *lunarText(void) {
    return applyReplacement(lunarDateString());
}

// —— 数据层 hook：STTelephonyStatusDomainSIMInfo 的 label / shortLabel ——
static NSArray *gOrig = nil;
static NSInteger gHookCalls = 0;

%hook STTelephonyStatusDomainSIMInfo
- (NSString *)label {
    NSString *orig = %orig;
    if (gHookCalls < 5) { writeLog([NSString stringWithFormat:@"[CALL] SIMInfo.label 原值=%@", orig]); gHookCalls++; }
    return lunarText();
}
- (NSString *)shortLabel {
    return lunarText();
}
%end

%hook _UIStatusBarStringView
- (void)setText:(id)text {
    NSString *s = [text isKindOfClass:[NSString class]] ? text : nil;
    if (isCarrierText(s)) {
        writeLog([NSString stringWithFormat:@"[REPLACE] setText %@ -> %@", s, lunarText()]);
        text = lunarText();
    }
    %orig;
}
- (void)setAttributedText:(id)text {
    NSString *s = [text isKindOfClass:[NSAttributedString class]] ? ((NSAttributedString *)text).string : nil;
    if (isCarrierText(s)) {
        writeLog([NSString stringWithFormat:@"[REPLACE] setAttributedText %@ -> %@", s, lunarText()]);
        text = [[NSAttributedString alloc] initWithString:lunarText()];
    }
    %orig;
}
%end

// 主动遍历替换
static void sweep(void) {
    UIApplication *app = [UIApplication sharedApplication];
    NSMutableSet *windows = [NSMutableSet set];
    for (UIScene *sc in app.connectedScenes) {
        if ([sc isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *ws = (UIWindowScene *)sc;
            for (UIWindow *w in ws.windows) [windows addObject:w];
        }
    }
    int replaced = 0;
    for (UIWindow *win in windows) {
        NSMutableArray *stack = [NSMutableArray arrayWithObject:win];
        while (stack.count) {
            UIView *v = stack.lastObject; [stack removeLastObject];
            NSString *cur = nil;
            if ([v respondsToSelector:@selector(attributedText)]) {
                NSAttributedString *at = [v performSelector:@selector(attributedText)];
                cur = at.string;
            }
            if (!cur.length && [v respondsToSelector:@selector(text)])
                cur = [v performSelector:@selector(text)];
            if (isCarrierText(cur)) {
                if ([v respondsToSelector:@selector(setText:)])
                    [v performSelector:@selector(setText:) withObject:lunarText()];
                replaced++;
            }
            for (UIView *sub in v.subviews) [stack addObject:sub];
        }
    }
    writeLog([NSString stringWithFormat:@"[SWEEP] 替换 %d 处", replaced]);
}

%ctor {
    writeLog(@"LunarCarrier 加载 (AXS Mac 编译版)");
    @autoreleasepool {
        for (NSNumber *n in @[@2.0, @5.0, @10.0]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(n.doubleValue * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ sweep(); });
        }
    }
}
