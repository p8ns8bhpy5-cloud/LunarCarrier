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

// 只 hook carrier 相关，不动 label/shortLabel（主副卡保持原样）
%hook STTelephonyStatusDomainSIMInfo
- (NSString *)carrierName {
    NSString *orig = %orig;
    writeLog([NSString stringWithFormat:@"[CALL] carrierName=%@", orig]);
    return lunarText();
}
- (NSString *)mobileOperatorName {
    NSString *orig = %orig;
    writeLog([NSString stringWithFormat:@"[CALL] mobileOperatorName=%@", orig]);
    return lunarText();
}
- (NSString *)serviceProviderName {
    NSString *orig = %orig;
    writeLog([NSString stringWithFormat:@"[CALL] serviceProviderName=%@", orig]);
    return lunarText();
}
%end

%hook UILabel
- (void)setText:(NSString *)text {
    if (isCarrierText(text)) {
        writeLog([NSString stringWithFormat:@"[REPLACE] UILabel.setText %@ -> %@", text, lunarText()]);
        text = lunarText();
    }
    %orig;
}
- (void)setAttributedText:(NSAttributedString *)text {
    if (isCarrierText(text.string)) {
        writeLog([NSString stringWithFormat:@"[REPLACE] UILabel.setAttributedText %@ -> %@", text.string, lunarText()]);
        text = [[NSAttributedString alloc] initWithString:lunarText()];
    }
    %orig;
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

static BOOL gDumped = NO;

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
    NSMutableArray *seenTexts = [NSMutableArray array];
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
            if (cur.length > 1 && cur.length < 50) [seenTexts addObject:cur];
            if (isCarrierText(cur)) {
                writeLog([NSString stringWithFormat:@"[FOUND] 类=%@ frame=%.0f,%.0f,%.0f,%.0f 父=%@ 文字=%@",
                          [v class], v.frame.origin.x, v.frame.origin.y, v.frame.size.width, v.frame.size.height,
                          [v.superview class], cur]);
                if ([v respondsToSelector:@selector(setAttributedText:)]) {
                    [v performSelector:@selector(setAttributedText:) withObject:[[NSAttributedString alloc] initWithString:lunarText()]];
                } else if ([v respondsToSelector:@selector(setText:)]) {
                    [v performSelector:@selector(setText:) withObject:lunarText()];
                }
                replaced++;
            }
            for (UIView *sub in v.subviews) [stack addObject:sub];
        }
    }
    if (!gDumped) {
        gDumped = YES;
        writeLog([NSString stringWithFormat:@"[DUMP] 看到的文字: %@", [seenTexts componentsJoinedByString:@", "]]);
    }
    if (replaced > 0) writeLog([NSString stringWithFormat:@"[SWEEP] 替换 %d 处", replaced]);
}

%ctor {
    writeLog(@"LunarCarrier 加载 (v9 省电)");
    // 不主动 sweep，只靠 UILabel setText: hook 被动拦截，不费电
}
