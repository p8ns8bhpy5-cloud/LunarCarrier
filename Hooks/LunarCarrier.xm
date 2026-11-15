#import "lunar.h"
#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import <CoreFoundation/CoreFoundation.h>
#import <substrate.h>

// 内嵌子集字体：浪漫雅圆（仅保留农历所需字形，其余已删除）
static const char *kLunarFontBase64 =
"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";

static UIFontDescriptor *gLunarFontDesc = nil;

// 锁屏状态：优先用 Darwin 通知判断；通知在本机未触发时回退到 y 坐标
static BOOL gLockObserved = NO;
static BOOL gIsLocked = YES;

static void lockStateCallback(CFNotificationCenterRef center, void *observer, CFStringRef name,
                              const void *object, CFDictionaryRef userInfo) {
    gLockObserved = YES;
    gIsLocked = (CFStringCompare(name, CFSTR("com.apple.springboard.lockcomplete"), 0) == kCFCompareEqualTo);
}

static void registerLunarFont(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSData *data = [[NSData alloc] initWithBase64EncodedString:[NSString stringWithUTF8String:kLunarFontBase64] options:0];
        if (!data.length) return;
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
        if (!provider) return;
        CGFontRef cgFont = CGFontCreateWithDataProvider(provider);
        if (cgFont) {
            CFErrorRef err = NULL;
            CTFontManagerRegisterGraphicsFont(cgFont, &err);
            CFRelease(cgFont);
        }
        CFRelease(provider);
        for (NSString *family in [UIFont familyNames]) {
            if ([family containsString:@"雅圆"] || [family containsString:@"ZhunYuan"]) {
                NSArray *names = [UIFont fontNamesForFamilyName:family];
                if (names.count) {
                    UIFont *ff = [UIFont fontWithName:names.firstObject size:14];
                    gLunarFontDesc = ff.fontDescriptor; break;
                }
            }
        }
        if (!gLunarFontDesc) {
            UIFont *f = [UIFont fontWithName:@"ZhunYuan" size:14] ?: [UIFont fontWithName:@"浪漫雅圆" size:14];
            gLunarFontDesc = f.fontDescriptor;
        }
    });
}

static UIFont *lunarFont(CGFloat size) {
    registerLunarFont();
    if (gLunarFontDesc) return [UIFont fontWithDescriptor:gLunarFontDesc size:size];
    return [UIFont systemFontOfSize:size];
}

static NSString *lunarText(void) {
    NSString *s = lunarDateString();
    NSRange yr = [s rangeOfString:@"年"];
    if (yr.location != NSNotFound) s = [s substringFromIndex:yr.location + 1];
    s = [s stringByReplacingOccurrencesOfString:@"十一月" withString:@"冬月"];
    s = [s stringByReplacingOccurrencesOfString:@"十二月" withString:@"腊月"];
    return s;
}

static NSAttributedString *lunarAttr(UIFont *base, CGFloat maxW, CGFloat maxH, UIColor *color) {
    CGFloat size = base.pointSize > 0 ? base.pointSize : 14;
    NSString *text = lunarText();
    UIFont *f = lunarFont(size);
    // 竖向适配：行高超过标签高度时按比例缩小（保底 0.7 倍），避免字形上下被裁
    if (maxH > 1 && f.lineHeight > maxH) {
        CGFloat fitted = size * (maxH / f.lineHeight);
        fitted = MAX(fitted, size * 0.7);
        f = lunarFont(fitted);
        size = fitted;
    }
    // 横向适配：文字宽度超过标签宽度时按比例缩小（保底 0.7 倍），避免右侧被裁
    if (maxW > 1) {
        CGSize fit = [text sizeWithAttributes:@{NSFontAttributeName: f}];
        if (fit.width > maxW) {
            CGFloat fitted = size * (maxW / fit.width);
            fitted = MAX(fitted, size * 0.7);
            f = lunarFont(fitted);
        }
    }
    // 颜色沿用标签原本的系统颜色；取不到才回退白色（不强制改色）
    UIColor *fg = color ?: [UIColor whiteColor];
    return [[NSAttributedString alloc] initWithString:text
                                         attributes:@{NSFontAttributeName: f,
                                                      NSForegroundColorAttributeName: fg}];
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

static BOOL shouldReplace(UILabel *label) {
    NSString *s = label.text.length ? label.text : label.attributedText.string;
    if (!isCarrier(s)) return NO;
    if (!inStatusBar(label)) return NO;
    // 通知可用时按锁屏状态判断；否则回退 y>10
    if (gLockObserved) return gIsLocked;
    return label.frame.origin.y > 10;
}

%ctor {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
        lockStateCallback, CFSTR("com.apple.springboard.lockcomplete"), NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
        lockStateCallback, CFSTR("com.apple.springboard.unlockcomplete"), NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately);
}

%hook UILabel
- (void)setText:(NSString *)text {
    if (shouldReplace(self)) {
        [self setAttributedText:lunarAttr(self.font, self.bounds.size.width, self.bounds.size.height, self.textColor)];
        return;
    }
    %orig;
}
- (void)setAttributedText:(NSAttributedString *)text {
    if (shouldReplace(self)) {
        self.numberOfLines = 1;
        self.lineBreakMode = NSLineBreakByClipping;
        self.clipsToBounds = NO;
        text = lunarAttr(self.font, self.bounds.size.width, self.bounds.size.height, self.textColor);
    }
    %orig;
}
%end
