//
//  XBHTTPResponse.h
//  XBNetwork
//
//  保存一次成功请求的协议响应、原始数据和解析结果。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 成功请求的完整结果，由 detailedCompletion 返回；失败时改从 NSError.userInfo 读取可用信息。
@interface XBHTTPResponse : NSObject

/// 实际发送的请求，包含编码后的 URL 和请求头；可能含敏感数据，未经脱敏不要直接上传日志。
/// Multipart 通常使用 HTTPBodyStream，HTTPBody 可为 nil；请勿为了查看内容读取该流。
@property (nonatomic, copy, readonly) NSURLRequest *URLRequest;
/// 服务器返回的 HTTP 状态和响应头。
@property (nonatomic, strong, readonly) NSHTTPURLResponse *HTTPResponse;
/// 未经转换的响应数据；空响应使用长度为 0 的 NSData。
@property (nonatomic, copy, readonly) NSData *data;
/// 按 responseType 解码的 JSON 对象、NSData 或 NSString；允许空响应且无字节时为 nil。
/// JSON 不会自动转为业务模型，服务端业务状态需自行检查。
@property (nonatomic, strong, readonly, nullable) id responseObject;
/// 从客户端准备创建任务到接收完整响应的耗时（秒），不含公共参数/适配器、解码及 UI 回调耗时。
@property (nonatomic, assign, readonly) NSTimeInterval duration;

/// 供解析器或测试构造结果；普通调用方直接使用 detailedCompletion 提供的对象，无需自行初始化。
- (instancetype)initWithURLRequest:(NSURLRequest *)URLRequest
                       HTTPResponse:(NSHTTPURLResponse *)HTTPResponse
                               data:(NSData *)data
                     responseObject:(nullable id)responseObject
                           duration:(NSTimeInterval)duration NS_DESIGNATED_INITIALIZER;
/// 响应必须绑定请求及 HTTP 元数据。
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
