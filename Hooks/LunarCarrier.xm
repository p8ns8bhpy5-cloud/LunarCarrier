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

// 判断是否应该替换这个 carrier label
// 规则：
//   1. 锁屏（y > 10，即 label 在 superview 里位置偏下）→ 替换
//   2. 任务栏（y <= 10）→ 只替换主卡（上方那行），用 window 坐标比较
static BOOL shouldReplace(UILabel *label) {
    CGFloat y = label.frame.origin.y;
    // 锁屏：y > 10
    if (y > 10) return YES;

    // 任务栏：用 window 坐标找最上面的 carrier label
    // 先算自己在 window 里的 y
    UIWindow *win = label.window;
    if (!win) return NO;
    CGRect r = [label convertRect:label.bounds toView:win];
    CGFloat winY = r.origin.y;

    // 遍历状态栏里所有 carrier label，找最小的 winY
    // 为了简单，用静态变量记录"主卡 winY"，第一次见到 carrier label 时定下来
    static CGFloat mainWinY = -1;
    static UIView *statusBarView = nil;

    UIView *sb = label;
    while (sb) {
        NSString *cn = NSStringFromClass([sb class]);
        if ([cn containsString:@"StatusBar"] && ![cn containsString:@"Item"]) break;
        sb = sb.superview;
    }
    if (sb != statusBarView) {
        statusBarView = sb;
        mainWinY = -1;  // 换了状态栏实例，重置
    }

    if (mainWinY < 0) {
        mainWinY = winY;  // 第一个见到的 carrier label 当主卡
        writeLog([NSString stringWithFormat:@"set mainWinY=%.1f text=%@", winY, label.text]);
        return YES;
    }

    // 距离主卡 winY 很近（< 15）认为是同一行/副卡，跳过
    CGFloat diff = fabs(winY - mainWinY);
    writeLog([NSString stringWithFormat:@"carrier winY=%.1f mainWinY=%.1f diff=%.1f text=%@", winY, mainWinY, diff, label.text]);
    if (diff < 15) {
        // 同一行附近——如果 y 比 mainWinY 小（更靠上），更新主卡
        if (winY < mainWinY) {
            mainWinY = winY;
            return YES;
        }
        return NO;  // 同一行但不是主卡
    }
    // 不同行——更靠上的才是主卡
    if (winY < mainWinY) {
        mainWinY = winY;
        return YES;
    }
    return NO;
}

%hook UILabel
- (void)setText:(NSString *)text {
    if (isCarrierText(text) && isInStatusBar(self) && shouldReplace(self)) {
        NSAttributedString *a = lunarAttributed(self.font);
        text = a.string;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setAttributedText:lunarAttributed(self.font)];
        });
    }
    %orig;
}
- (void)setAttributedText:(NSAttributedString *)text {
    if (isCarrierText(text.string) && isInStatusBar(self) && shouldReplace(self)) {
        text = lunarAttributed(self.font);
    }
    %orig;
}
%end

%ctor {
    writeLog(@"LunarCarrier v40 锁屏+任务栏主卡");
}
