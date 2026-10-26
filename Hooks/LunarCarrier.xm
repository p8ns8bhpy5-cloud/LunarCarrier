#import "lunar.h"
#import <UIKit/UIKit.h>
#import <substrate.h>

static NSString *lunarText(void) {
    NSString *s = lunarDateString();
    NSRange yr = [s rangeOfString:@"年"];
    if (yr.location != NSNotFound) s = [s substringFromIndex:yr.location + 1];
    s = [s stringByReplacingOccurrencesOfString:@"十一月" withString:@"冬月"];
    s = [s stringByReplacingOccurrencesOfString:@"十二月" withString:@"腊月"];
    return s;
}

static NSAttributedString *lunarAttr(UIFont *base) {
    UIFont *f = base ?: [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    UIFont *bf = [UIFont fontWithDescriptor:[[f fontDescriptor] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold] size:f.pointSize];
    return [[NSAttributedString alloc] initWithString:lunarText()
                                         attributes:@{NSFontAttributeName: bf,
                                                      NSForegroundColorAttributeName: [UIColor whiteColor]}];
}

static BOOL isCarrier(NSString *s) {
    if (!s.length) return NO;
    for (NSString *k in @[@"移动", @"联通", @"电信", @"全球通", @"CMCC"])
        if ([s containsString:k]) return YES;
    return NO;
}

static BOOL inStatusBar(UIView *v) {
    while (v) {
        NSString *cn = NSStringFromClass([v class]);
        if ([cn containsString:@"StatusBar"]) return YES;
        v = v.superview;
    }
    return NO;
}

%hook UILabel
- (void)setText:(NSString *)text {
    // 只替换锁屏：carrier label 在锁屏 y>10，任务栏 y=0
    if (isCarrier(text) && inStatusBar(self) && self.frame.origin.y > 10) {
        NSAttributedString *a = lunarAttr(self.font);
        text = a.string;
        dispatch_async(dispatch_get_main_queue(), ^{ [self setAttributedText:lunarAttr(self.font)]; });
    }
    %orig;
}
- (void)setAttributedText:(NSAttributedString *)text {
    if (isCarrier(text.string) && inStatusBar(self) && self.frame.origin.y > 10) {
        text = lunarAttr(self.font);
    }
    %orig;
}
%end
