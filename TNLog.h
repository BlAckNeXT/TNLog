//
//  TNLog.h
//  TNLog
//
//  Created by JasonJ on 15/6/10.
//  Copyright (c) 2015年 Sysw1n. All rights reserved.
//

#import <Foundation/Foundation.h>


//Debug
#define TNLogD(desStr) [TNLog logLevel:LOG_LEVEL_DEBUG LogInfo:[NSString stringWithFormat:@"Function:%s Line:%d Des:%@",__func__,__LINE__,desStr]]

//Info
#define TNLogI(desStr) [TNLog logLevel:LOG_LEVEL_INFO LogInfo:[NSString stringWithFormat:@"Function:%s Line:%d Des:%@",__func__,__LINE__,desStr]]
//Warning
#define TNLogW(desStr) [TNLog logLevel:LOG_LEVEL_WARNING LogInfo:[NSString stringWithFormat:@"Function:%s Line:%d Des:%@",__func__,__LINE__,desStr]]
//Error
#define TNLogE(desStr) [TNLog logLevel:LOG_LEVEL_ERR LogInfo:[NSString stringWithFormat:@"Function:%s Line:%d Des:%@",__func__,__LINE__,desStr]]

//日志等级
typedef enum
{
    LOG_LEVEL_NONE      = 0,  //None
    LOG_LEVEL_DEBUG     = 1,  //Debug
    LOG_LEVEL_INFO      = 2,  //Info
    LOG_LEVEL_WARNING   = 3,  //Warning
    LOG_LEVEL_ERR       = 4,  //Error
} TNLogLevel;


@interface TNLog : NSObject


/**
 *  log初始化函数，在系统启动时调用
 *  @param userid  用户名片id
 */
+ (void)logInitWithUserid:(NSString *)userid;


/**
 *  设置要记录的log级别
 *
 *  @param level 要设置的log级别
 */
+ (void)setLogLevel:(TNLogLevel)level;


/**
 *  记录系统crash的Log函数
 *
 *  @param exception 系统异常
 */
+ (void)logCrash:(NSException*)exception;

/**
 *  log记录函数
 *
 *  @param level  log所属的等级
 *  @param format 具体记录log的格式以及内容
 */
+ (void)logLevel:(TNLogLevel)level LogInfo:(NSString *)logInfo;

/********************************
 * error code list:
 * 101 -- 文件不存在
 * 102 -- 操作失败
 * 103 -- 网络错误
 ********************************
 */

/**
 *  把log.txt打包为.zip文件
 *
 *  @param logName log.txt的文件全名
 */
+ (void)archiveLogWithLogName:(NSString *)logName
                        error:(void(^)(NSDictionary *errDict))errorblock;

/**
 *  把.zip文件上传到服务器
 *
 *  @param zipName log.zip的文件全名
 */
+ (void)uploadLogWithZipName:(NSString *)zipName
                       error:(void(^)(NSDictionary *errDict))errorblock;


/**
 *  根据文件名删除本地存的日志文件
 *
 *  @param fileName 要删除的文件全名
 *  @param error    发生错误时的回调函数
 */
+ (void)deleteLogWithFileName:(NSString *)fileName
                        error:(void(^)(NSDictionary *errDict))errorblock;








@end
