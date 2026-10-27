//
//  XBHTTPRequestBuilder.h
//  XBNetwork
//
//  将 XBHTTPRequest 确定性地转换为 NSURLRequest；公共参数已由 XBNetwork 预先解析。
//

#import <Foundation/Foundation.h>
#import "XBHTTPRequest.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const XBHTTPRequestBuilderErrorDomain;

typedef NS_ENUM(NSInteger, XBHTTPRequestBuilderErrorCode) {
    XBHTTPRequestBuilderErrorInvalidURL = 1,
    XBHTTPRequestBuilderErrorBodyNotAllowed,
    XBHTTPRequestBuilderErrorInvalidBody,
    XBHTTPRequestBuilderErrorCommonParametersCannotMerge,
    XBHTTPRequestBuilderErrorEncodingFailed,
    XBHTTPRequestBuilderErrorInvalidRequest
};

@interface XBHTTPRequestBuilder : NSObject

/// 构建最终请求。失败时不会产生半成品请求，error 会说明协议配置或编码错误。
- (nullable NSMutableURLRequest *)buildURLRequestFromRequest:(XBHTTPRequest *)request
                                                       error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
