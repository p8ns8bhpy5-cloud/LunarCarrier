//
//  lunar.h
//  LunarCarrier 农历换算接口
//
#ifndef LUNAR_H
#define LUNAR_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// 返回当前公历日期对应的农历字符串（含生肖年），例如 "马年九月十六"、"马年闰二月十五"
NSString *lunarDateString(void);

#ifdef __cplusplus
}
#endif

#endif
