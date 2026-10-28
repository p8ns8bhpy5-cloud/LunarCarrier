#import "lunar.h"
#import <UIKit/UIKit.h>
#import <substrate.h>
#import <sqlite3.h>

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

static NSDictionary *prefs(void) {
    return [NSDictionary dictionaryWithContentsOfFile:kPrefsPath] ?: @{};
}

static BOOL prefBool(NSString *key, BOOL def) {
    NSNumber *n = prefs()[key];
    return n ? n.boolValue : def;
}
static CGFloat prefFloat(NSString *key, CGFloat def) {
    NSNumber *n = prefs()[key];
    return n ? n.doubleValue : def;
}
static UIColor *prefColor(NSString *key, CGFloat defAlpha) {
    NSString *hex = prefs()[key];
    if (hex.length == 7 && [hex hasPrefix:@"#"]) {
        unsigned r,g,b;
        sscanf([hex UTF8String], "#%2x%2x%2x", &r,&g,&b);
        return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:defAlpha];
    }
    return [UIColor whiteColor];
}

// —— 农历文本（去年份，十一月=冬月，十二月=腊月）——
static NSString *lunarMainText(void) {
    NSString *s = lunarDateString();
    // 去年份部分（"X年"）
    NSRange yr = [s rangeOfString:@"年"];
    if (yr.location != NSNotFound) s = [s substringFromIndex:yr.location + 1];
    s = [s stringByReplacingOccurrencesOfString:@"十一月" withString:@"冬月"];
    s = [s stringByReplacingOccurrencesOfString:@"十二月" withString:@"腊月"];
    return s;
}

// 生肖字（取"X年"第一个字）
static NSString *zodiacChar(void) {
    NSString *s = lunarDateString();
    NSRange yr = [s rangeOfString:@"年"];
    if (yr.location != NSNotFound && yr.location >= 1)
        return [s substringWithRange:NSMakeRange(yr.location-1, 1)];
    return @"";
}

// —— 天气（从系统 Weather sqlite 读当前条件）——
static NSString *weatherIcon(void) {
    NSString *path = @"/var/mobile/Library/Weather/Weather.sqlite";
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return @"";
    sqlite3 *db = NULL;
    if (sqlite3_open([path UTF8String], &db) != SQLITE_OK) return @"";
    NSString *icon = @"";
    NSString *sql = @"SELECT icon FROM ZCITY ORDER BY ZLASTUPDATE DESC LIMIT 1;";
    sqlite3_stmt *stmt = NULL;
    if (sqlite3_prepare_v2(db, [sql UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            const char *c = (const char *)sqlite3_column_text(stmt, 0);
            if (c) {
                int ic = atoi(c);
                // 简单映射
                switch (ic) {
                    case 1: case 32: icon = @"☀️"; break;
                    case 2: case 30: icon = @"🌤"; break;
                    case 3: case 28: case 29: icon = @"☁️"; break;
                    case 6: case 9: case 11: case 12: icon = @"🌧"; break;
                    case 13: case 14: case 16: case 42: case 46: icon = @"🌨"; break;
                    case 15: case 17: case 35: case 41: case 46: icon = @"🌩"; break;
                    default: icon = @"🌡"; break;
                }
            }
        }
        sqlite3_finalize(stmt);
    }
    sqlite3_close(db);
    return icon;
}

// —— 自定义 label ——
static UILabel *gLunarLabel;
static UILabel *gWeatherLabel;
static UIView *gAnchorView;

static BOOL isCarrierText(NSString *s) {
    if (!s.length) return NO;
    for (NSString *k in @[@"移动", @"联通", @"电信", @"全球通", @"CMCC",
                          @"China Mobile", @"China Unicom", @"China Telecom"])
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

static void rebuildLabels(UIView *carrierView) {
    if (!carrierView) return;
    gAnchorView = carrierView;
    UIView *container = carrierView.superview;
    if (!container) return;

    CGRect base = carrierView.frame;
    CGFloat lSize = prefFloat(@"LunarSize", 14);
    CGFloat wSize = prefFloat(@"WeatherSize", 14);
    CGFloat lOx = prefFloat(@"LunarOffsetX", 0);
    CGFloat lOy = prefFloat(@"LunarOffsetY", 0);
    CGFloat wOx = prefFloat(@"WeatherOffsetX", 0);
    CGFloat wOy = prefFloat(@"WeatherOffsetY", 0);

    if (!gLunarLabel) {
        gLunarLabel = [[UILabel alloc] init];
        gLunarLabel.font = [UIFont systemFontOfSize:lSize weight:UIFontWeightBold];
        gLunarLabel.textColor = prefColor(@"LunarColor", 1);
        gLunarLabel.textAlignment = NSTextAlignmentNatural;
        [container addSubview:gLunarLabel];
    }
    gLunarLabel.hidden = !prefBool(@"LunarEnabled", YES);
    gLunarLabel.frame = CGRectMake(base.origin.x + lOx, base.origin.y + lOy,
                                    400, base.size.height ?: 20);
    NSString *z = prefBool(@"LunarShowZodiac", NO) ? zodiacChar() : @"";
    gLunarLabel.text = z.length ? [NSString stringWithFormat:@"%@ %@", z, lunarMainText()]
                                : lunarMainText();
    gLunarLabel.font = [UIFont systemFontOfSize:lSize weight:UIFontWeightBold];
    gLunarLabel.textColor = prefColor(@"LunarColor", 1);

    if (!gWeatherLabel) {
        gWeatherLabel = [[UILabel alloc] init];
        gWeatherLabel.font = [UIFont systemFontOfSize:wSize weight:UIFontWeightMedium];
        gWeatherLabel.textAlignment = NSTextAlignmentNatural;
        [container addSubview:gWeatherLabel];
    }
    gWeatherLabel.hidden = !prefBool(@"WeatherEnabled", NO);
    CGFloat wx = base.origin.x + wOx;
    if (!gLunarLabel.hidden) {
        [gLunarLabel sizeToFit];
        wx = gLunarLabel.frame.origin.x + gLunarLabel.frame.size.width + 4 + wOx;
    }
    gWeatherLabel.frame = CGRectMake(wx, base.origin.y + wOy, 60, base.size.height ?: 20);
    gWeatherLabel.text = weatherIcon();
    gWeatherLabel.font = [UIFont systemFontOfSize:wSize weight:UIFontWeightMedium];
    gWeatherLabel.textColor = prefColor(@"WeatherColor", 1);
}

%hook _UIStatusBarStringView
- (void)setText:(id)text {
    NSString *s = [text isKindOfClass:[NSString class]] ? text : nil;
    // 锁屏 carrier：y>10 才接管；任务栏不动
    if (isCarrierText(s) && inStatusBar((UIView *)self) && ((UIView *)self).frame.origin.y > 10) {
        // 隐藏原 label：用空格占位
        text = @" ";
        %orig;
        dispatch_async(dispatch_get_main_queue(), ^{ rebuildLabels((UIView *)self); });
        return;
    }
    %orig;
}
- (void)setAttributedText:(id)text {
    NSString *s = [text isKindOfClass:[NSAttributedString class]] ? ((NSAttributedString *)text).string : nil;
    if (isCarrierText(s) && inStatusBar((UIView *)self) && ((UIView *)self).frame.origin.y > 10) {
        text = [[NSAttributedString alloc] initWithString:@" "];
        %orig;
        dispatch_async(dispatch_get_main_queue(), ^{ rebuildLabels((UIView *)self); });
        return;
    }
    %orig;
}
%end

%ctor {
    writeLog(@"LunarCarrier v43 加载");
    // 定时刷新（天气/农历日期变化）
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:60 repeats:YES block:^(NSTimer *t) {
            if (gAnchorView) rebuildLabels(gAnchorView);
        }];
    });
}
