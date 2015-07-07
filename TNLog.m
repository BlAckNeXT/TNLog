//
//  TNLog.m
//  TNLog
//
//  Created by JasonJ on 15/6/10.
//  Copyright (c) 2015年 Sysw1n. All rights reserved.
//

#import "TNLog.h"
#import <UIKit/UIKit.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#import <zipzap.h>
#import <AFNetworking.h>

#define kDocumentsDirectory [NSSearchPathForDirectoriesInDomains(NSDocumentationDirectory, NSUserDomainMask, YES) objectAtIndex:0]
#define kLogDirectory [kDocumentsDirectory stringByAppendingString:@"/log/"]


#ifdef DEBUG
//Debug默认记录的日志等级为LogLevelD。
static TNLogLevel LogLevel = LOG_LEVEL_DEBUG;
#else
//正常模式默认记录的日志等级为LogLevelI。
static TNLogLevel LogLevel = LOG_LEVEL_INFO;
#endif

// 打印队列
static dispatch_once_t logQueueCreatOnce;
static dispatch_queue_t k_operationQueue;

static NSString *logFilePath = nil;
static NSString *logDic      = nil;
static NSString *crashDic    = nil;
static NSString *userId      = nil;

@implementation TNLog

/**
 *  log初始化函数，在系统启动时调用
 *  @param userid  用户名片id
 */
+ (void)logInitWithUserid:(NSString *)userid
{
    if (!logFilePath){
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:kLogDirectory]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:kLogDirectory
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
        }
    
        
        logDic   = kLogDirectory;
        crashDic = kLogDirectory;
        userId   = userid;
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd"];
        dateFormatter.timeZone   = [NSTimeZone timeZoneWithAbbreviation:@"GMT+0000"];
        NSString *fileNamePrefix = [dateFormatter stringFromDate:[NSDate date]];
        NSString *fileName       = [NSString stringWithFormat:@"TNLog_%@_%@.log",userid,fileNamePrefix];
        NSString *filePath = [kLogDirectory stringByAppendingPathComponent:fileName];
        
        logFilePath = filePath;
#if DEBUG
        NSLog(@"LogPath: %@", logFilePath);
#endif
        // 如果不存在,创建文件
        if (![[NSFileManager defaultManager] fileExistsAtPath:logFilePath]) {
            [[NSFileManager defaultManager] createFileAtPath:logFilePath
                                                    contents:nil
                                                  attributes:nil];

        }
        
        dispatch_once(&logQueueCreatOnce, ^{
            k_operationQueue =  dispatch_queue_create("com.syswin.app.operationqueue", DISPATCH_QUEUE_SERIAL);
        });
    }
}


/**
 *  设置要记录的log级别
 *
 *  @param level level 要设置的log级别
 */
+ (void)setLogLevel:(TNLogLevel)level
{
    LogLevel = level;
}


/**
 *  记录系统crash的Log函数
 *
 *  @param exception 系统异常
 */
+ (void)logCrash:(NSException*)exception
{
    if (exception == nil)
    {
        return;
    }
    
#ifdef DEBUG
    NSLog(@"CRASH: %@", exception);
    NSLog(@"Stack Trace: %@", [exception callStackSymbols]);
#endif
    
    if (!crashDic) {
        crashDic = kLogDirectory;
    }
    
    NSString *fileName = [NSString stringWithFormat:@"CRASH_%@_%@.log", userId,[[TNLog nowBeijingTime] description]];
    NSString *filePath = [crashDic stringByAppendingString:fileName];
    NSString *content  = [[NSString stringWithFormat:@"CRASH: %@\n", exception] stringByAppendingString:[NSString stringWithFormat:@"Stack Trace: %@\n", [exception callStackSymbols]]];
    
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *languages       = [defaults objectForKey:@"AppleLanguages"];
    NSString *phoneLanguage  = [languages objectAtIndex:0];
    
    content = [content stringByAppendingString:[NSString stringWithFormat:@"iPhone:%@  iOS Version:%@ Language:%@",[TNLog platformString], [[UIDevice currentDevice] systemVersion],phoneLanguage]];
//    [TNLog logLevel:LOG_LEVEL_ERR LogInfo:content,nil];
    NSError *error = nil;
    [content writeToFile:filePath
              atomically:YES
                encoding:NSUTF8StringEncoding
                   error:&error];
    
    if (error) {
#if DEBUG
        NSLog(@"error is %@",error);
#endif
//        [TNLog logLevel:LOG_LEVEL_ERR LogInfo:@"CRASH LOG CREAT ERR INFO IS %@",error];
        
    }
}

/**
 *  log记录函数
 *
 *  @param level  log所属的等级
 *  @param format 具体记录log的格式以及内容
 */
+ (void)logLevel:(TNLogLevel)level LogInfo:(NSString *)logInfo
{
    dispatch_async(k_operationQueue, ^{
        
        if (level >= LogLevel) {
            NSString *log        = [[TNLog TNLogFormatPrefix:level] stringByAppendingString:logInfo];
            NSString *contentStr = log;
            NSString *contentN   = [contentStr stringByAppendingString:@"\n"];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            NSString *content    = [NSString stringWithFormat:@"%@ %@", [dateFormatter stringFromDate:[TNLog nowBeijingTime]], contentN];
            // 拼接文本到文件里
            NSFileHandle *file   = [NSFileHandle fileHandleForUpdatingAtPath:logFilePath];
            [file seekToEndOfFile];
            [file writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
            [file closeFile];
#ifdef DEBUG
            NSLog(@"%@", content);
#endif
        }
        
    });
    
}


/**
 *  log日志信息等级前缀
 *
 *  @param logLevel 设置的log级别
 */
+ (NSString*)TNStringFromLogLevel:(TNLogLevel)logLevel
{
    switch (logLevel)
    {
        case LOG_LEVEL_NONE     :return @"NONE";
        case LOG_LEVEL_DEBUG    :return @"DEBUG";
        case LOG_LEVEL_INFO     :return @"INFO";
        case LOG_LEVEL_WARNING  :return @"WARNING";
        case LOG_LEVEL_ERR      :return @"ERROR";
    }
    return @"";
}


/**
 *  log日志信息等级前缀
 *
 *  @param logLevel 设置的log级别
 */
+ (NSString*)TNLogFormatPrefix:(TNLogLevel)logLevel
{
    return [NSString stringWithFormat:@"[%@] ", [TNLog TNStringFromLogLevel:logLevel]];
}


#pragma mark - Handle Log Methods
/**
 *  把log打包为.zip文件
 *
 *  @param logName log的文件全名
 */
+ (void)archiveLogWithLogName:(NSString *)logName
                        error:(void(^)(NSDictionary *errDict))errorblock
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@%@",kLogDirectory,logName]]) {
        [TNLog errorBlockWithErrDict:@{@"error_code":@"101",
                                       @"error_msg" :@"file is not exist!"} error:errorblock];
        return;
    }
    ZZArchive *newArchive = [[ZZArchive alloc] initWithURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@.zip",kLogDirectory,logName]]
                                                   options:@{ZZOpenOptionsCreateIfMissingKey : @YES}
                                                     error:nil];
    // 通过指定的路径读取文本内容
    NSString *logStr = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@%@",kLogDirectory,logName] encoding:NSUTF8StringEncoding error:nil];
    
    NSError *error = nil;
    [newArchive updateEntries:@[
                                [ZZArchiveEntry archiveEntryWithFileName:logName
                                                                compress:YES
                                                               dataBlock:^(NSError** error)
                                 {
                                     return [logStr dataUsingEncoding:NSUTF8StringEncoding];
                                 }]
                                ]
                        error:&error];
    if (error) {
        NSLog(@"archive log error, error = %@",error);
        [TNLog errorBlockWithErrDict:@{@"error_code":@"102",
                                       @"error_msg" :[NSString stringWithFormat:@"archive log error, error =%@",error]} error:errorblock];
    }
}

/**
 *  把.zip文件上传到服务器
 *
 *  @param zipName log.zip的文件全名
 */
+ (void)uploadLogWithZipName:(NSString *)zipName
                       error:(void(^)(NSDictionary *errDict))errorblock
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@%@",kLogDirectory,zipName]]) {
        [TNLog errorBlockWithErrDict:@{@"error_code":@"101",
                                       @"error_msg" :@"file is not exist!"} error:errorblock];
        return;
    }
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer             = [AFHTTPResponseSerializer serializer];
    manager.requestSerializer              = [AFHTTPRequestSerializer serializer];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"text/html",@"application/x-www-form-urlencoded",@"text/plain",@"application/json",nil];
    NSURL *filePath = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@",kLogDirectory,zipName]];
    [manager POST:@"http://logupload.systoon.com/fileUploadServlet" parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileURL:filePath name:@"zip" error:nil];
    } success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Success: %@", responseObject);
        NSLog(@"operation.responseString: %@",operation.responseString);
        
        NSString *result = [[NSString alloc] initWithData:responseObject  encoding:NSUTF8StringEncoding];
        NSLog(@"result =%@",result);

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        [TNLog errorBlockWithErrDict:@{@"error_code":@"103",
                                       @"error_msg" :[NSString stringWithFormat:@"%@",error]} error:errorblock];
    }];
}

/**
 *  根据文件名删除本地存的日志文件
 *
 *  @param fileName 要删除的文件全名
 */
+ (void)deleteLogWithFileName:(NSString *)fileName
                        error:(void(^)(NSDictionary *errDict))errorblock
{
    NSString *filePath = [NSString stringWithFormat:@"%@%@",kLogDirectory,fileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:filePath
                                                   error:&error];
        if (error) {
            NSLog(@"delete log error ,error = %@",error);
            [TNLog errorBlockWithErrDict:@{@"error_code":@"102",
                                           @"error_msg" :[NSString stringWithFormat:@"%@",error]}
                                   error:errorblock];
        }
    }else{
        NSLog(@"file path not exist! delete fail!");
        [TNLog errorBlockWithErrDict:@{@"error_code":@"101",
                                       @"error_msg" :@"file path not exist! delete fail!"}
                               error:errorblock];
    }

}

/**
 *  发生错误时block回调函数
 *
 */
+ (void)errorBlockWithErrDict:(NSDictionary *)errDic
                        error:(void(^)(NSDictionary *errDict))error
{
    error(errDic);
}



#pragma mark - Device Info
/**
 *  获取当前时间
 */
+ (NSDate *)nowBeijingTime
{
    NSTimeZone *AA    = [NSTimeZone timeZoneWithAbbreviation:@"GMT+0000"];
    NSInteger seconds = [AA secondsFromGMTForDate: [NSDate date]];
    return [NSDate dateWithTimeInterval: seconds sinceDate: [NSDate date]];
}

/**
 *  获取机型信息
 */
+ (NSString *)platform
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    return platform;
}

/**
 *  机型信息
 */
+ (NSString *)platformString
{
    NSString *platform = [TNLog platform];
    if ([platform isEqualToString:@"iPhone1,1"]) return @"iPhone 2G (A1203)";
    if ([platform isEqualToString:@"iPhone1,2"]) return @"iPhone 3G (A1241/A1324)";
    if ([platform isEqualToString:@"iPhone2,1"]) return @"iPhone 3GS (A1303/A1325)";
    if ([platform isEqualToString:@"iPhone3,1"]) return @"iPhone 4 (A1332)";
    if ([platform isEqualToString:@"iPhone3,2"]) return @"iPhone 4 (A1332)";
    if ([platform isEqualToString:@"iPhone3,3"]) return @"iPhone 4 (A1349)";
    if ([platform isEqualToString:@"iPhone4,1"]) return @"iPhone 4S (A1387/A1431)";
    if ([platform isEqualToString:@"iPhone5,1"]) return @"iPhone 5 (A1428)";
    if ([platform isEqualToString:@"iPhone5,2"]) return @"iPhone 5 (A1429/A1442)";
    if ([platform isEqualToString:@"iPhone5,3"]) return @"iPhone 5c (A1456/A1532)";
    if ([platform isEqualToString:@"iPhone5,4"]) return @"iPhone 5c (A1507/A1516/A1526/A1529)";
    if ([platform isEqualToString:@"iPhone6,1"]) return @"iPhone 5s (A1453/A1533)";
    if ([platform isEqualToString:@"iPhone6,2"]) return @"iPhone 5s (A1457/A1518/A1528/A1530)";
    if ([platform isEqualToString:@"iPhone7,1"]) return @"iPhone 6 Plus (A1522/A1524)";
    if ([platform isEqualToString:@"iPhone7,2"]) return @"iPhone 6 (A1549/A1586)";
    
    if ([platform isEqualToString:@"iPod1,1"])   return @"iPod Touch 1G (A1213)";
    if ([platform isEqualToString:@"iPod2,1"])   return @"iPod Touch 2G (A1288)";
    if ([platform isEqualToString:@"iPod3,1"])   return @"iPod Touch 3G (A1318)";
    if ([platform isEqualToString:@"iPod4,1"])   return @"iPod Touch 4G (A1367)";
    if ([platform isEqualToString:@"iPod5,1"])   return @"iPod Touch 5G (A1421/A1509)";
    
    if ([platform isEqualToString:@"iPad1,1"])   return @"iPad 1G (A1219/A1337)";
    
    if ([platform isEqualToString:@"iPad2,1"])   return @"iPad 2 (A1395)";
    if ([platform isEqualToString:@"iPad2,2"])   return @"iPad 2 (A1396)";
    if ([platform isEqualToString:@"iPad2,3"])   return @"iPad 2 (A1397)";
    if ([platform isEqualToString:@"iPad2,4"])   return @"iPad 2 (A1395+New Chip)";
    if ([platform isEqualToString:@"iPad2,5"])   return @"iPad Mini 1G (A1432)";
    if ([platform isEqualToString:@"iPad2,6"])   return @"iPad Mini 1G (A1454)";
    if ([platform isEqualToString:@"iPad2,7"])   return @"iPad Mini 1G (A1455)";
    
    if ([platform isEqualToString:@"iPad3,1"])   return @"iPad 3 (A1416)";
    if ([platform isEqualToString:@"iPad3,2"])   return @"iPad 3 (A1403)";
    if ([platform isEqualToString:@"iPad3,3"])   return @"iPad 3 (A1430)";
    if ([platform isEqualToString:@"iPad3,4"])   return @"iPad 4 (A1458)";
    if ([platform isEqualToString:@"iPad3,5"])   return @"iPad 4 (A1459)";
    if ([platform isEqualToString:@"iPad3,6"])   return @"iPad 4 (A1460)";
    
    if ([platform isEqualToString:@"iPad4,1"])   return @"iPad Air (A1474)";
    if ([platform isEqualToString:@"iPad4,2"])   return @"iPad Air (A1475)";
    if ([platform isEqualToString:@"iPad4,3"])   return @"iPad Air (A1476)";
    if ([platform isEqualToString:@"iPad4,4"])   return @"iPad Mini 2G (A1489)";
    if ([platform isEqualToString:@"iPad4,5"])   return @"iPad Mini 2G (A1490)";
    if ([platform isEqualToString:@"iPad4,6"])   return @"iPad Mini 2G (A1491)";
    
    if ([platform isEqualToString:@"i386"])      return @"iPhone Simulator";
    if ([platform isEqualToString:@"x86_64"])    return @"iPhone Simulator";
    
    return platform;
}





@end
