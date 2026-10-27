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

/// 内部响应解析器，只判断 HTTP 与解码结果；不识别 JSON 中的业务 code/message 或模型类型。
@interface XBHTTPResponseParser : NSObject

/// 校验 HTTP 状态、空响应规则和解码类型，错误通过 error 输出。
/// 失败返回 nil，可用请求/响应/数据写入错误 userInfo；空响应允许成功时 responseObject 为 nil。
- (nullable XBHTTPResponse *)parseData:(nullable NSData *)data
                              response:(nullable NSURLResponse *)response
                            URLRequest:(NSURLRequest *)URLRequest
                               request:(XBHTTPRequest *)request
                              duration:(NSTimeInterval)duration
                                 error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
