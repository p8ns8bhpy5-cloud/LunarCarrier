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

// 把农历字符串拆成 年/月/日 三段，分别替换
// 输入如：马年九月十七 / 马年闰二月初一
static NSString *applyReplacement(NSString *input) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];

    // 找"年"字位置，年段 = 到"年"为止
    NSRange yearRange = [input rangeOfString:@"年"];
    NSString *yearPart = yearRange.location != NSNotFound ? [input substringToIndex:yearRange.location + 1] : @"";
    NSString *rest = yearRange.location != NSNotFound ? [input substringFromIndex:yearRange.location + 1] : input;

    // 日段 = 末尾（初一..三十，1-3字）
    // 中文日名：初一..初十(2字) 十一..二十(2字) 廿一..三十(2字) — 都是2字
    // 但"二十""三十"是2字，"初十"是2字。取最后2字作为日段
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

// 跟踪主卡 label 实例：第一次遇到的 carrier label 是主卡，记录它；后续只替换主卡那个
static NSMutableSet *gMainLabels = nil;
static BOOL gMainLocked = NO;

%hook UILabel
- (void)setText:(NSString *)text {
    if (isCarrierText(text)) {
        @synchronized(self) {
            if (!gMainLabels) gMainLabels = [NSMutableSet set];
            if (!gMainLocked) {
                // 还没确定主卡：第一个 carrier label 就是主卡
                [gMainLabels addObject:[NSValue valueWithNonretainedObject:self]];
                gMainLocked = YES;
                writeLog([NSString stringWithFormat:@"[MAIN] 锁定主卡 label=%p", self]);
            }
            BOOL isMain = [gMainLabels containsObject:[NSValue valueWithNonretainedObject:self]];
            if (isMain) {
                text = lunarText();
            }
        }
    }
    %orig;
}
- (void)setAttributedText:(NSAttributedString *)text {
    if (isCarrierText(text.string)) {
        @synchronized(self) {
            if (!gMainLabels) gMainLabels = [NSMutableSet set];
            if (!gMainLocked) {
                [gMainLabels addObject:[NSValue valueWithNonretainedObject:self]];
                gMainLocked = YES;
                writeLog([NSString stringWithFormat:@"[MAIN-A] 锁定主卡 label=%p", self]);
            }
            BOOL isMain = [gMainLabels containsObject:[NSValue valueWithNonretainedObject:self]];
            if (isMain) {
                text = [[NSAttributedString alloc] initWithString:lunarText()];
            }
        }
    }
    %orig;
}
%end

%ctor {
    writeLog(@"LunarCarrier 加载 (v13 三段替换+主卡锁定)");
}
