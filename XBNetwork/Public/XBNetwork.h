//
//  XBNetwork.h
//  XBNetwork
//
//  业务层唯一的网络调用入口。常规接口使用明确的便捷方法，特殊协议通过
//  XBHTTPRequest 描述参数位置后仍由本类统一发送。
//

#import <Foundation/Foundation.h>
#import "XBNetworkError.h"
#import "XBNetworkConfiguration.h"
#import "XBHTTPResponse.h"

@class XBHTTPRequest;
@class XBHTTPResponse;

NS_ASSUME_NONNULL_BEGIN

typedef void (^XBNetworkResultCompletion)(id _Nullable responseObject,
                                          NSError * _Nullable error);
typedef void (^XBNetworkProgress)(NSProgress *progress);
typedef void (^XBNetworkDetailedCompletion)(XBHTTPResponse * _Nullable response,
                                            NSError * _Nullable error);

@interface XBNetwork : NSObject
+ (instancetype)sharedNetwork;
- (instancetype)initWithConfiguration:(XBNetworkConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
/// Permanently closes this instance and cancels its tasks. Other instances are unaffected.
- (void)invalidateAndCancel;
/// GET 请求：业务参数和 配置的公共参数统一放入 URL Query。
- (nullable NSURLSessionTask *)GET:(NSString *)URLString
                        parameters:(nullable NSDictionary<NSString *, id> *)parameters
                        completion:(nullable XBNetworkResultCompletion)completion;

/// 带接口专属 Header 的 GET 请求，公共参数规则与普通 GET 一致。
- (nullable NSURLSessionTask *)GET:(NSString *)URLString
                         parameters:(nullable NSDictionary<NSString *, id> *)parameters
                            headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                         completion:(nullable XBNetworkResultCompletion)completion;

/// POST Form 请求：业务参数和 配置的公共参数统一放入表单 Body。
- (nullable NSURLSessionTask *)POSTForm:(NSString *)URLString
                             parameters:(nullable NSDictionary<NSString *, id> *)parameters
                             completion:(nullable XBNetworkResultCompletion)completion;

/// 带接口专属 Header 的 POST Form 请求，公共参数规则与普通 POST Form 一致。
- (nullable NSURLSessionTask *)POSTForm:(NSString *)URLString
                             parameters:(nullable NSDictionary<NSString *, id> *)parameters
                                headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                             completion:(nullable XBNetworkResultCompletion)completion;

/// POST JSON 请求：业务参数和 配置的公共参数统一放入 JSON Body。
- (nullable NSURLSessionTask *)POSTJSON:(NSString *)URLString
                             parameters:(nullable NSDictionary<NSString *, id> *)parameters
                             completion:(nullable XBNetworkResultCompletion)completion;

/// 带接口专属 Header 的 POST JSON 请求，公共参数规则与普通 POST JSON 一致。
- (nullable NSURLSessionTask *)POSTJSON:(NSString *)URLString
                              parameters:(nullable NSDictionary<NSString *, id> *)parameters
                                 headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                              completion:(nullable XBNetworkResultCompletion)completion;

/// POST Query + JSON 请求：Query 和 JSON Body 保持独立，避免参数位置被隐式改变。
- (nullable NSURLSessionTask *)POSTQueryJSON:(NSString *)URLString
                             queryParameters:(nullable NSDictionary<NSString *, id> *)queryParameters
                                  JSONObject:(id)JSONObject
                                  completion:(nullable XBNetworkResultCompletion)completion;

/// POST Query + Form 请求：业务标识放在 Query，配置的公共参数及表单字段放在 Body。
- (nullable NSURLSessionTask *)POSTQueryForm:(NSString *)URLString
                              queryParameters:(nullable NSDictionary<NSString *, id> *)queryParameters
                               formParameters:(nullable NSDictionary<NSString *, id> *)formParameters
                                   completion:(nullable XBNetworkResultCompletion)completion;

/// 发送完整请求描述。Raw Data、Multipart 等特殊接口使用该入口。
- (nullable NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                                completion:(nullable XBNetworkResultCompletion)completion;

/// 进度和完成回调均异步投递到配置的回调队列。
- (nullable NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                            uploadProgress:(nullable XBNetworkProgress)uploadProgress
                                completion:(nullable XBNetworkResultCompletion)completion;

/// 需要读取状态码、响应头或原始字节时使用；发送入口仍然只有 XBNetwork。
- (nullable NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                            uploadProgress:(nullable XBNetworkProgress)uploadProgress
                        detailedCompletion:(nullable XBNetworkDetailedCompletion)completion;

/// 取消统一网络会话中仍在执行的所有任务。
- (void)cancelAllRequests;


/// Convenience methods use sharedNetwork with default configuration.
/// GET 请求：业务参数和 配置的公共参数统一放入 URL Query。
+ (nullable NSURLSessionTask *)GET:(NSString *)URLString
                        parameters:(nullable NSDictionary<NSString *, id> *)parameters
                        completion:(nullable XBNetworkResultCompletion)completion;

/// 带接口专属 Header 的 GET 请求，公共参数规则与普通 GET 一致。
+ (nullable NSURLSessionTask *)GET:(NSString *)URLString
                         parameters:(nullable NSDictionary<NSString *, id> *)parameters
                            headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                         completion:(nullable XBNetworkResultCompletion)completion;

/// POST Form 请求：业务参数和 配置的公共参数统一放入表单 Body。
+ (nullable NSURLSessionTask *)POSTForm:(NSString *)URLString
                             parameters:(nullable NSDictionary<NSString *, id> *)parameters
                             completion:(nullable XBNetworkResultCompletion)completion;

/// 带接口专属 Header 的 POST Form 请求，公共参数规则与普通 POST Form 一致。
+ (nullable NSURLSessionTask *)POSTForm:(NSString *)URLString
                             parameters:(nullable NSDictionary<NSString *, id> *)parameters
                                headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                             completion:(nullable XBNetworkResultCompletion)completion;

/// POST JSON 请求：业务参数和 配置的公共参数统一放入 JSON Body。
+ (nullable NSURLSessionTask *)POSTJSON:(NSString *)URLString
                             parameters:(nullable NSDictionary<NSString *, id> *)parameters
                             completion:(nullable XBNetworkResultCompletion)completion;

/// 带接口专属 Header 的 POST JSON 请求，公共参数规则与普通 POST JSON 一致。
+ (nullable NSURLSessionTask *)POSTJSON:(NSString *)URLString
                              parameters:(nullable NSDictionary<NSString *, id> *)parameters
                                 headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                              completion:(nullable XBNetworkResultCompletion)completion;

/// POST Query + JSON 请求：Query 和 JSON Body 保持独立，避免参数位置被隐式改变。
+ (nullable NSURLSessionTask *)POSTQueryJSON:(NSString *)URLString
                             queryParameters:(nullable NSDictionary<NSString *, id> *)queryParameters
                                  JSONObject:(id)JSONObject
                                  completion:(nullable XBNetworkResultCompletion)completion;

/// POST Query + Form 请求：业务标识放在 Query，配置的公共参数及表单字段放在 Body。
+ (nullable NSURLSessionTask *)POSTQueryForm:(NSString *)URLString
                              queryParameters:(nullable NSDictionary<NSString *, id> *)queryParameters
                               formParameters:(nullable NSDictionary<NSString *, id> *)formParameters
                                   completion:(nullable XBNetworkResultCompletion)completion;

/// 发送完整请求描述。Raw Data、Multipart 等特殊接口使用该入口。
+ (nullable NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                                completion:(nullable XBNetworkResultCompletion)completion;

/// 进度和完成回调均异步投递到配置的回调队列。
+ (nullable NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                            uploadProgress:(nullable XBNetworkProgress)uploadProgress
                                completion:(nullable XBNetworkResultCompletion)completion;

/// 需要读取状态码、响应头或原始字节时使用；发送入口仍然只有 XBNetwork。
+ (nullable NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                            uploadProgress:(nullable XBNetworkProgress)uploadProgress
                        detailedCompletion:(nullable XBNetworkDetailedCompletion)completion;

/// 取消统一网络会话中仍在执行的所有任务。
+ (void)cancelAllRequests;


@end
NS_ASSUME_NONNULL_END
