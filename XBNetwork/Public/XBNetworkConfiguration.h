#import <Foundation/Foundation.h>
#import "XBHTTPRequest.h"
#import "XBNetworkLogger.h"
NS_ASSUME_NONNULL_BEGIN
/**
 每次请求发送前提供公共参数，例如应用版本、语言或业务需要的用户标识。

 仅当请求的 commonParameterPlacement 为 Query 或 Body 时调用；None 不调用。
 在调用 sendRequest 的线程同步执行，应快速返回，不要在这里等待网络或刷新 Token。
 request 是组件复制的请求描述。返回字典与指定位置的参数合并，同名时请求参数优先。
 组件不会自动读取用户、设备或鉴权信息；动态值应在此 Block 内按当前状态读取。
 */
typedef NSDictionary<NSString *, id> * _Nonnull (^XBNetworkCommonParametersProvider)(XBHTTPRequest *request);
/**
 在默认请求头、公共参数合并之后，编码请求之前，修改本次请求的私有副本。

 可添加 Authorization 请求头、签名，或修改 URL、Body、超时等配置。
 在发送请求的线程同步执行；多个线程发送时，此 Block 也可能并发执行。
 返回 YES 继续发送；返回 NO 拦截请求，可通过 *error 说明原因，组件将其包装为
 XBNetworkErrorRequestBuildFailed 并异步回调。需要先刷新 Token 时，应在宿主完成后再发请求。
 不要长期持有或在异步任务中修改传入的 request，也不要假定这里已经得到编码后的字节。
 */
typedef BOOL (^XBNetworkRequestAdapter)(XBHTTPRequest *request, NSError * _Nullable * _Nullable error);

/**
 一个 XBNetwork 实例的配置。先设置属性，再传入 initWithConfiguration:。

 XBNetwork 初始化时复制配置；此后修改原配置不会更新已有实例。
 Block 被复制，logger 和 completionQueue 仍引用同一对象；捕获持有网络实例的宿主时
 应使用弱引用以避免循环引用。需要独立鉴权、Cookie 配置或取消范围时，创建不同实例。
 */
@interface XBNetworkConfiguration : NSObject <NSCopying>
/// 所有请求共用的请求头，默认空字典。单请求 headers 按大小写不敏感覆盖同名字段。
/// Body 编码器生成的 Content-Type 优先；Cookie 是否发送还受请求的 cookiePolicy 限制。
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *defaultHeaders;
/// 普通请求的默认等待超时，单位秒，初始 20；request.timeout 为非正值或非有限值时使用。
/// 最终值仍无效时回退到 20 秒。限制整次传输耗时请设置 request.totalTimeout。
@property (nonatomic) NSTimeInterval defaultTimeout;
/// 完成和上传进度回调异步投递到此队列，默认主队列；构建失败也遵循此规则。
/// 建议使用串行队列；配置并发队列时，接收端须自行处理回调并发和执行顺序。
@property (nonatomic, strong) dispatch_queue_t completionQueue;
/// 会话配置，默认 defaultSessionConfiguration；赋值和网络实例初始化时复制。
/// 可设置 URLCache、protocolClasses 等；Cookie 开关由每个请求的 cookiePolicy 决定。
/// 组件使用带完成回调的 dataTask，不提供后台会话上传/下载与文件落盘接口。
@property (nonatomic, copy) NSURLSessionConfiguration *sessionConfiguration;
/// 公共参数提供者，默认 nil；合并位置由请求决定，具体规则见上方 Block 说明。
@property (nonatomic, copy, nullable) XBNetworkCommonParametersProvider commonParametersProvider;
/// 请求适配器，默认 nil；在公共参数合并后执行，用于鉴权、签名或拒绝发送。
@property (nonatomic, copy, nullable) XBNetworkRequestAdapter requestAdapter;
/// 可选日志接收者，默认 nil；线程与字段含义见 XBNetworkLogger.h。
@property (nonatomic, strong, nullable) id<XBNetworkLogger> logger;
@end
NS_ASSUME_NONNULL_END
