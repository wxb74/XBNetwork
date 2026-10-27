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

/// 简化完成回调：成功时 error 为 nil，responseObject 类型由 request.responseType 决定。
/// 允许空响应时，即使成功 responseObject 也可以为 nil；请以 error 判断成功与否。
/// 默认异步回到主队列；不会自动解析服务端业务 code，也不会将 JSON 转成业务模型。
typedef void (^XBNetworkResultCompletion)(id _Nullable responseObject,
                                          NSError * _Nullable error);
/// 上传字节进度，异步投递到 completionQueue。totalUnitCount 未知时为 -1。
/// 进度不表示服务端已处理成功；任务结束后丢弃排队进度，不保证最后一次一定是 100%。
typedef void (^XBNetworkProgress)(NSProgress *progress);
/// 完整完成回调：成功返回 XBHTTPResponse；失败 response 为 nil，协议详情从 error.userInfo 读取。
/// 非 nil 的完成回调只交付一次，包括构建失败、主动取消及超时与网络完成竞争的场景。
typedef void (^XBNetworkDetailedCompletion)(XBHTTPResponse * _Nullable response,
                                            NSError * _Nullable error);

/**
 请求发送入口。简单 GET/Form/JSON 接口使用便捷方法；上传或特殊协议使用 sendRequest:。

 所有 URL 必须是完整的 http/https 地址；组件没有 baseURL，也不自动附加鉴权或业务公共参数。
 类方法使用默认共享实例；需要配置公共参数、请求头、日志或独立取消范围时，请创建实例并持有。
 例如：XBNetwork *network = [[XBNetwork alloc] initWithConfiguration:configuration];

 发送方法同步复制配置、合并公共参数、执行适配器并编码，然后返回已启动的 NSURLSessionTask。
 返回 nil 表示未创建任务，但非 nil 的 completion 仍会异步执行；无需调用 resume。
 可用 [task cancel] 取消单个请求。组件不自动重试、刷新 Token 或判断响应 JSON 中的业务状态。
 */
@interface XBNetwork : NSObject
/// 全进程共享实例，首次访问时创建，使用默认配置；与自行创建的实例互不影响。
+ (instancetype)sharedNetwork;
/// 复制配置并创建实例。初始化后更改原 configuration 不会更新此实例。
- (instancetype)initWithConfiguration:(XBNetworkConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
/// 等同于传入新的默认配置：20 秒等待超时、主队列回调、无公共参数、无日志接收者。
- (instancetype)init;
/// 永久关闭本实例并取消任务；不可再次启用。之后发送返回取消错误，其他实例不受影响。
/// 若只需取消当前任务并继续复用实例，请使用 cancelAllRequests。
- (void)invalidateAndCancel;
/**
 GET 查询：parameters 和公共参数放在 URL 的 ?key=value 部分，同名时 parameters 优先。
 @param URLString 完整 HTTP/HTTPS 地址，可已有固定 Query；动态参数无需手动百分号编码。
 @param parameters 本次查询字段；nil 视为空字典。所有请求均使用配置的公共参数规则。
 @param completion 可为 nil；默认主队列异步回调，成功通常返回 JSON 对象。
 @return 已启动的任务；配置或编码失败时返回 nil，并通过 completion 异步交付错误。
 */
- (nullable NSURLSessionTask *)GET:(NSString *)URLString
                        parameters:(nullable NSDictionary<NSString *, id> *)parameters
                        completion:(nullable XBNetworkResultCompletion)completion;

/// GET 查询并指定本次请求头；headers 可为 nil，同名字段按大小写不敏感覆盖 defaultHeaders。
- (nullable NSURLSessionTask *)GET:(NSString *)URLString
                         parameters:(nullable NSDictionary<NSString *, id> *)parameters
                            headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                         completion:(nullable XBNetworkResultCompletion)completion;

/// POST 表单：parameters 和公共参数编码为 application/x-www-form-urlencoded 请求体。
/// parameters 为 nil 时按空字典处理；编码器管理 Content-Type，无需手动设置。
- (nullable NSURLSessionTask *)POSTForm:(NSString *)URLString
                             parameters:(nullable NSDictionary<NSString *, id> *)parameters
                             completion:(nullable XBNetworkResultCompletion)completion;

/// POST 表单并指定请求头；字段与普通 POSTForm 一致，headers 覆盖默认头但不能破坏编码器的 Content-Type。
- (nullable NSURLSessionTask *)POSTForm:(NSString *)URLString
                             parameters:(nullable NSDictionary<NSString *, id> *)parameters
                                headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                             completion:(nullable XBNetworkResultCompletion)completion;

/// POST JSON 字典：parameters 和公共参数编码为 application/json 请求体，nil 按空字典处理。
/// 若服务端要求 JSON 数组根对象，请使用显式请求并设置 commonParameterPlacement 为 None 或 Query。
- (nullable NSURLSessionTask *)POSTJSON:(NSString *)URLString
                             parameters:(nullable NSDictionary<NSString *, id> *)parameters
                             completion:(nullable XBNetworkResultCompletion)completion;

/// POST JSON 字典并指定请求头；参数规则与普通 POSTJSON 一致。
- (nullable NSURLSessionTask *)POSTJSON:(NSString *)URLString
                              parameters:(nullable NSDictionary<NSString *, id> *)parameters
                                 headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                              completion:(nullable XBNetworkResultCompletion)completion;

/// POST 混合协议：queryParameters 与公共参数放 URL，JSONObject 单独作为 JSON 请求体。
/// JSONObject 必须是合法的字典或数组；公共参数不会被插入这个 JSON 对象。
- (nullable NSURLSessionTask *)POSTQueryJSON:(NSString *)URLString
                             queryParameters:(nullable NSDictionary<NSString *, id> *)queryParameters
                                  JSONObject:(id)JSONObject
                                  completion:(nullable XBNetworkResultCompletion)completion;

/// POST 混合协议：queryParameters 只放 URL；formParameters 与公共参数放表单请求体。
/// 两个字典可为 nil；Query 与 Body 的同名字段各自保留，不跨位置合并。
- (nullable NSURLSessionTask *)POSTQueryForm:(NSString *)URLString
                              queryParameters:(nullable NSDictionary<NSString *, id> *)queryParameters
                               formParameters:(nullable NSDictionary<NSString *, id> *)formParameters
                                   completion:(nullable XBNetworkResultCompletion)completion;

/// 发送显式请求，适用于 PUT/PATCH/DELETE/HEAD、Raw、Multipart 或自定义响应格式。
/// Query/Body 完全由 request 指定，显式请求默认不合并公共参数；需按协议主动选择合并位置。
- (nullable NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                                completion:(nullable XBNetworkResultCompletion)completion;

/// 发送显式请求并接收上传进度；进度和完成回调均异步投递到 completionQueue。
/// 只关心结果时 uploadProgress 可为 nil；进度语义见 XBNetworkProgress。
- (nullable NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                            uploadProgress:(nullable XBNetworkProgress)uploadProgress
                                completion:(nullable XBNetworkResultCompletion)completion;

/// 发送显式请求并返回完整响应，适用于读取状态码、响应头、原始字节或耗时的场景。
/// 失败时 response 为 nil；用 XBNetworkErrorResponseKey 等键从 error.userInfo 获取可用协议数据。
- (nullable NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                            uploadProgress:(nullable XBNetworkProgress)uploadProgress
                        detailedCompletion:(nullable XBNetworkDetailedCompletion)completion;

/// 异步枚举并取消本实例两个 Cookie 会话中的当前任务；实例仍可使用，其他实例不受影响。
/// 已完成的结果无法撤回；不要把此方法当作与后续新请求之间的同步屏障。
- (void)cancelAllRequests;


// 以下类方法转发给 sharedNetwork，参数、返回值和回调规则与上方同名实例方法一致。
// 在自建实例中配置的公共参数、鉴权或日志，不会应用到这些类方法。
/// 共享实例 GET 查询；parameters 放 URL Query，默认不附加宿主公共参数。
+ (nullable NSURLSessionTask *)GET:(NSString *)URLString
                        parameters:(nullable NSDictionary<NSString *, id> *)parameters
                        completion:(nullable XBNetworkResultCompletion)completion;

/// 共享实例 GET 查询，额外指定本次请求头。
+ (nullable NSURLSessionTask *)GET:(NSString *)URLString
                         parameters:(nullable NSDictionary<NSString *, id> *)parameters
                            headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                         completion:(nullable XBNetworkResultCompletion)completion;

/// 共享实例 POST 表单；parameters 放 Form Body。
+ (nullable NSURLSessionTask *)POSTForm:(NSString *)URLString
                             parameters:(nullable NSDictionary<NSString *, id> *)parameters
                             completion:(nullable XBNetworkResultCompletion)completion;

/// 共享实例 POST 表单，额外指定本次请求头。
+ (nullable NSURLSessionTask *)POSTForm:(NSString *)URLString
                             parameters:(nullable NSDictionary<NSString *, id> *)parameters
                                headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                             completion:(nullable XBNetworkResultCompletion)completion;

/// 共享实例 POST JSON 字典；parameters 放 JSON Body。
+ (nullable NSURLSessionTask *)POSTJSON:(NSString *)URLString
                             parameters:(nullable NSDictionary<NSString *, id> *)parameters
                             completion:(nullable XBNetworkResultCompletion)completion;

/// 共享实例 POST JSON 字典，额外指定本次请求头。
+ (nullable NSURLSessionTask *)POSTJSON:(NSString *)URLString
                              parameters:(nullable NSDictionary<NSString *, id> *)parameters
                                 headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                              completion:(nullable XBNetworkResultCompletion)completion;

/// 共享实例 POST：queryParameters 放 URL，JSONObject 单独作为 JSON Body。
+ (nullable NSURLSessionTask *)POSTQueryJSON:(NSString *)URLString
                             queryParameters:(nullable NSDictionary<NSString *, id> *)queryParameters
                                  JSONObject:(id)JSONObject
                                  completion:(nullable XBNetworkResultCompletion)completion;

/// 共享实例 POST：queryParameters 放 URL，formParameters 放 Form Body。
+ (nullable NSURLSessionTask *)POSTQueryForm:(NSString *)URLString
                              queryParameters:(nullable NSDictionary<NSString *, id> *)queryParameters
                               formParameters:(nullable NSDictionary<NSString *, id> *)formParameters
                                   completion:(nullable XBNetworkResultCompletion)completion;

/// 使用共享实例发送显式请求；参数位置及响应规则由 request 决定。
+ (nullable NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                                completion:(nullable XBNetworkResultCompletion)completion;

/// 使用共享实例发送显式请求并接收上传进度，默认在主队列回调。
+ (nullable NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                            uploadProgress:(nullable XBNetworkProgress)uploadProgress
                                completion:(nullable XBNetworkResultCompletion)completion;

/// 使用共享实例发送显式请求并返回完整响应，默认在主队列回调。
+ (nullable NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                            uploadProgress:(nullable XBNetworkProgress)uploadProgress
                        detailedCompletion:(nullable XBNetworkDetailedCompletion)completion;

/// 仅取消 sharedNetwork 的当前任务，不影响自建实例；共享实例仍可继续发送。
+ (void)cancelAllRequests;


@end
NS_ASSUME_NONNULL_END
