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

static NSString *lunarText(void) {
    NSString *s = lunarDateString();
    NSRange yr = [s rangeOfString:@"年"];
    if (yr.location != NSNotFound) {
        s = [s substringFromIndex:yr.location + 1];
    }
    NSDictionary *map = @{@"十一月":@"冬月", @"十二月":@"腊月"};
    for (NSString *k in map) {
        s = [s stringByReplacingOccurrencesOfString:k withString:map[k]];
    }
    return s;
}

static NSAttributedString *lunarAttributed(UIFont *baseFont) {
    UIFont *f = baseFont ?: [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    UIFont *boldF = [UIFont fontWithDescriptor:[[f fontDescriptor] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold] size:f.pointSize];
    return [[NSAttributedString alloc] initWithString:lunarText()
                                         attributes:@{NSFontAttributeName: boldF,
                                                      NSForegroundColorAttributeName: [UIColor whiteColor]}];
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

// 只替换锁屏：锁屏 carrier label 的 y 坐标 > 10（约17.7），任务栏 y=0
static BOOL isLockScreenCarrier(UILabel *label) {
    CGFloat y = label.frame.origin.y;
    return y > 10;
}

%hook UILabel
- (void)setText:(NSString *)text {
    if (isCarrierText(text) && isInStatusBar(self) && isLockScreenCarrier(self)) {
        NSAttributedString *a = lunarAttributed(self.font);
        text = a.string;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setAttributedText:lunarAttributed(self.font)];
        });
    }
    %orig;
}
- (void)setAttributedText:(NSAttributedString *)text {
    if (isCarrierText(text.string) && isInStatusBar(self) && isLockScreenCarrier(self)) {
        text = lunarAttributed(self.font);
    }
    %orig;
}
%end

%ctor {
    writeLog(@"LunarCarrier v39 只锁屏");
}
