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

// 农历字符串：去掉"X年"，月名替换
static NSString *lunarText(void) {
    NSString *s = lunarDateString();  // 如 "马年九月十七"
    NSRange yr = [s rangeOfString:@"年"];
    if (yr.location != NSNotFound) {
        s = [s substringFromIndex:yr.location + 1];  // 去掉年
    }
    // 月名替换
    NSDictionary *map = @{@"十一月":@"冬月", @"十二月":@"腊月"};
    for (NSString *k in map) {
        s = [s stringByReplacingOccurrencesOfString:k withString:map[k]];
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

// 只替换状态栏内的 carrier label
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
    if (isCarrierText(text) && isInStatusBar(self)) {
        text = lunarText();
    }
    %orig;
}
- (void)setAttributedText:(NSAttributedString *)text {
    if (isCarrierText(text.string) && isInStatusBar(self)) {
        text = [[NSAttributedString alloc] initWithString:lunarText()];
    }
    %orig;
}
%end

%ctor {
    writeLog(@"LunarCarrier v28 精简版（无设置，只显示月日）");
}
