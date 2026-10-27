//
//  XBHTTPResponseParser.h
//  XBNetwork
//
//  校验 HTTP 协议结果并按请求声明解析响应数据。
//

#import <Foundation/Foundation.h>
#import "XBHTTPRequest.h"
#import "XBHTTPResponse.h"

NS_ASSUME_NONNULL_BEGIN

@interface XBHTTPResponseParser : NSObject

/// 校验 HTTP 状态、空响应规则和解码类型，错误通过 error 输出。
- (nullable XBHTTPResponse *)parseData:(nullable NSData *)data
                              response:(nullable NSURLResponse *)response
                            URLRequest:(NSURLRequest *)URLRequest
                               request:(XBHTTPRequest *)request
                              duration:(NSTimeInterval)duration
                                 error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
