//
//  XBHTTPRequest.h
//  XBNetwork
//
//  一个请求的完整协议描述。该对象不负责发送请求。
//

#import <Foundation/Foundation.h>
#import "XBHTTPBody.h"

NS_ASSUME_NONNULL_BEGIN

/// 支持的 HTTP 方法；请求数据放在 URL 还是 Body，仍须由 queryParameters/body 指定。
typedef NS_ENUM(NSUInteger, XBHTTPMethod) {
    XBHTTPMethodGET = 0,
    XBHTTPMethodPOST,
    XBHTTPMethodPUT,
    XBHTTPMethodPATCH,
    XBHTTPMethodDELETE,
    XBHTTPMethodHEAD
};

/// configuration.commonParametersProvider 返回的字段应合并到哪里；显式请求默认为 None。
typedef NS_ENUM(NSUInteger, XBCommonParameterPlacement) {
    /// 不调用公共参数提供者，也不添加公共参数；适用于完全自行控制协议的接口。
    XBCommonParameterPlacementNone = 0,
    /// 公共参数与 queryParameters 合并写入 URL；同名时 queryParameters 优先。
    XBCommonParameterPlacementQuery,
    /// 公共参数与 Form、JSON 字典或 Multipart 普通字段合并；同名时本次请求字段优先。
    /// None Body、Raw 和 JSON 数组不支持此模式，会返回构建失败；可改为 Query 或 None。
    XBCommonParameterPlacementBody
};

typedef NS_ENUM(NSUInteger, XBHTTPCookiePolicy) {
    /// 不读取、不发送、不保存系统共享 Cookie，请求的安全默认值。
    XBHTTPCookiePolicyDisabled = 0,
    /// 开启自动 Cookie 处理；使用 sessionConfiguration 配置的 CookieStorage，未提供时用系统共享存储。
    /// 仅在服务端明确要求 Cookie 时选择，不影响同实例中 Disabled 请求的隔离会话。
    XBHTTPCookiePolicySystem
};

typedef NS_ENUM(NSUInteger, XBHTTPResponseType) {
    /// 将响应解析为 NSDictionary、NSArray 或 JSON 基础类型。
    XBHTTPResponseTypeJSON = 0,
    /// 保留服务器返回的原始字节，适用于图片、文件等非 JSON 接口。
    XBHTTPResponseTypeData,
    /// 使用 UTF-8 将响应解析为 NSString。
    XBHTTPResponseTypeString
};

/// 供请求构建器统一转换 HTTP Method，业务代码不需要直接调用。
FOUNDATION_EXPORT NSString *XBHTTPMethodString(XBHTTPMethod method);

/// 列表工厂的等待数据超时，8 秒；不是所有 GET 请求的默认值。
FOUNDATION_EXPORT NSTimeInterval const XBHTTPListRequestTimeout;
/// 列表工厂的整次传输总预算，10 秒；与上面的等待数据超时同时生效。
FOUNDATION_EXPORT NSTimeInterval const XBHTTPListTotalTimeout;

/**
 一次请求的可配置描述，本对象不发送网络请求，完成配置后交给 XBNetwork 的 sendRequest:。

 Query 是 URL 中的 ?key=value 部分，Body 是请求体；两者独立，切换 method 不会移动参数。
 发送前组件复制描述并同步编码；发送后修改原描述不会改变已发出的请求或响应解析规则。
 配置和复制期间不要从其他线程同时修改可变对象；Form/Query 字典的 copy 不保证递归深拷贝。
 */
@interface XBHTTPRequest : NSObject <NSCopying>

/// 完整的 http/https 绝对地址，必须有 host；不支持相对路径或自动拼接 baseURL。
/// 可包含固定 Query；动态字段放 queryParameters，由组件编码，避免手动编码两次。
@property (nonatomic, copy) NSString *URLString;
/// HTTP 方法，默认 GET；GET/HEAD 不能携带 Body，其他方法也不会自动生成 Body。
@property (nonatomic, assign) XBHTTPMethod method;
/// URL 查询字段，默认空字典；按 AFNetworking 规则百分号编码并追加，支持数组等嵌套参数。
/// URL 已有同名 Query 不会被此字典移除；固定字段与动态字段应避免重复配置。
@property (nonatomic, copy) NSDictionary<NSString *, id> *queryParameters;
/// 明确指定 Form、JSON、Raw Data 或 Multipart；默认不携带 Body。
@property (nonatomic, copy) XBHTTPBody *body;
/// 本次请求头，默认空字典；键和值必须是字符串，按大小写不敏感覆盖默认头。
/// Body 生成的 Content-Type 优先；Disabled 模式下即使手动传 Cookie 也会被过滤。
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *headers;
/// 等待数据的超时，单位秒，默认 0 表示使用 configuration.defaultTimeout（初始 20 秒）。
/// 非有限值也回退到默认配置；这是系统请求超时，不是整次传输的硬性时间上限。
@property (nonatomic, assign) NSTimeInterval timeout;
/// 从客户端创建任务到完成的总预算，单位秒，默认 0；仅有限且大于 0 的值启用额外计时。
/// 包含传输等待与接收，不包含 Provider/Adapter 等发送前工作或完成后的 UI 处理。
@property (nonatomic, assign) NSTimeInterval totalTimeout;
/// 控制 NSURLRequest 的缓存读写策略，默认遵循系统协议缓存策略。
@property (nonatomic, assign) NSURLRequestCachePolicy cachePolicy;
/// 公共参数合并位置，默认 None；仅设置 Provider 并不会让显式请求自动加入公共参数。
@property (nonatomic, assign) XBCommonParameterPlacement commonParameterPlacement;
/// Cookie 策略；默认为 Disabled。切换后由网络客户端选择对应的 Session。
@property (nonatomic, assign) XBHTTPCookiePolicy cookiePolicy;
/// 指定成功响应的解析方式，默认按 JSON 处理。
@property (nonatomic, assign) XBHTTPResponseType responseType;
/// 默认 NO；接受空数据时设 YES，此时成功的 responseObject 为 nil。
/// HEAD、204 不会自动开启；必须同时满足 acceptableStatusCodes 才算成功。
@property (nonatomic, assign) BOOL allowsEmptyResponse;
/// 可接受的 HTTP 状态码，默认 200～299；空集合表示不接受任何状态码。
/// 这里只判断 HTTP 层，JSON 内的业务 code 由宿主处理。
@property (nonatomic, copy) NSIndexSet *acceptableStatusCodes;

/// 创建请求描述；默认无 Body、无公共参数、禁用 Cookie、解析 JSON、不允许空响应。
/// 配置完成后调用 [network sendRequest:request completion:...]，工厂方法本身不发送请求。
+ (instancetype)requestWithURLString:(NSString *)URLString method:(XBHTTPMethod)method;

/// 创建采用列表超时策略的描述（也适用于用 POST 查询的列表）：8 秒等待、10 秒总预算。
/// 只有显式使用此工厂才启用；仍需设置参数位置、Body 和公共参数合并方式。
+ (instancetype)listRequestWithURLString:(NSString *)URLString method:(XBHTTPMethod)method;

@end

NS_ASSUME_NONNULL_END
