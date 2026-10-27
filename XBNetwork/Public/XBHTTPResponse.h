//
//  XBHTTPResponse.h
//  XBNetwork
//
//  保存一次成功请求的协议响应、原始数据和解析结果。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XBHTTPResponse : NSObject

/// 实际发送的请求，可用于排查最终 URL、Header 和 Body。
@property (nonatomic, copy, readonly) NSURLRequest *URLRequest;
/// 服务器返回的 HTTP 状态和响应头。
@property (nonatomic, strong, readonly) NSHTTPURLResponse *HTTPResponse;
/// 未经转换的响应数据；空响应使用长度为 0 的 NSData。
@property (nonatomic, copy, readonly) NSData *data;
/// 根据 XBHTTPRequest.responseType 生成的 JSON、NSData 或 NSString。
@property (nonatomic, strong, readonly, nullable) id responseObject;
/// 从任务开始到收到完整响应所消耗的秒数。
@property (nonatomic, assign, readonly) NSTimeInterval duration;

/// 构造一次请求的完整响应快照。
- (instancetype)initWithURLRequest:(NSURLRequest *)URLRequest
                       HTTPResponse:(NSHTTPURLResponse *)HTTPResponse
                               data:(NSData *)data
                     responseObject:(nullable id)responseObject
                           duration:(NSTimeInterval)duration NS_DESIGNATED_INITIALIZER;
/// 响应必须绑定请求及 HTTP 元数据。
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
