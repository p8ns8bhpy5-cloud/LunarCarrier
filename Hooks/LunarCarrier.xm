#import "lunar.h"
#import <UIKit/UIKit.h>
#import <substrate.h>

// rootless 偏好路径
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

// 把农历字符串拆成 年/月/日 三段，分别替换
// 输入如：马年九月十七 / 马年闰二月初一
static NSString *applyReplacement(NSString *input) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    static BOOL gLogged = NO;
    if (!gLogged) {
        gLogged = YES;
        writeLog([NSString stringWithFormat:@"[PREFS] %@", prefs]);
    }

    // 找"年"字位置，年段 = 到"年"为止（含"年"）
    NSRange yearRange = [input rangeOfString:@"年"];
    NSString *yearPart = yearRange.location != NSNotFound ? [input substringToIndex:yearRange.location + 1] : @"";
    NSString *rest = yearRange.location != NSNotFound ? [input substringFromIndex:yearRange.location + 1] : input;

    // 日段 = 末尾2字（初一..三十 都是2字）
    NSString *dayPart = @"";
    NSString *monthPart = rest;
    if (rest.length >= 2) {
        dayPart = [rest substringFromIndex:rest.length - 2];
        monthPart = [rest substringToIndex:rest.length - 2];
    }

    // 分别替换
    if ([prefs[@"RemoveLeapChar"] boolValue]) {
        monthPart = [monthPart stringByReplacingOccurrencesOfString:@"闰" withString:@""];
    }
    for (int i = 1; i <= 3; i++) {
        NSString *find = prefs[[NSString stringWithFormat:@"Find%d", i]];
        NSString *repl = prefs[[NSString stringWithFormat:@"Replace%d", i]] ?: @"";
        if (!find.length) continue;
        if (i == 1) yearPart = [yearPart stringByReplacingOccurrencesOfString:find withString:repl];
        else if (i == 2) monthPart = [monthPart stringByReplacingOccurrencesOfString:find withString:repl];
        else dayPart = [dayPart stringByReplacingOccurrencesOfString:find withString:repl];
    }

    NSString *result = [NSString stringWithFormat:@"%@%@%@", yearPart, monthPart, dayPart];
    if (!gLogged) writeLog([NSString stringWithFormat:@"[RESULT] %@ -> %@", input, result]);
    return result;
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

// 所有 carrier label 都替换
%hook UILabel
- (void)setText:(NSString *)text {
    if (isCarrierText(text)) {
        text = lunarText();
    }
    %orig;
}
- (void)setAttributedText:(NSAttributedString *)text {
    if (isCarrierText(text.string)) {
        text = [[NSAttributedString alloc] initWithString:lunarText()];
    }
    %orig;
}
%end

%ctor {
    writeLog(@"LunarCarrier 加载 (v14 全部替换+prefs日志)");
}
