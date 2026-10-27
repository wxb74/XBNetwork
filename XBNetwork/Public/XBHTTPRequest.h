//
//  XBHTTPRequest.h
//  XBNetwork
//
//  一个请求的完整协议描述。该对象不负责发送请求。
//

#import <Foundation/Foundation.h>
#import "XBHTTPBody.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, XBHTTPMethod) {
    XBHTTPMethodGET = 0,
    XBHTTPMethodPOST,
    XBHTTPMethodPUT,
    XBHTTPMethodPATCH,
    XBHTTPMethodDELETE,
    XBHTTPMethodHEAD
};

typedef NS_ENUM(NSUInteger, XBCommonParameterPlacement) {
    /// 不自动添加 公共参数。
    XBCommonParameterPlacementNone = 0,
    /// 公共参数与业务 Query 合并后写入 URL。
    XBCommonParameterPlacementQuery,
    /// 公共参数与 Form、JSON 或 Multipart 字典合并后写入 Body。
    XBCommonParameterPlacementBody
};

typedef NS_ENUM(NSUInteger, XBHTTPCookiePolicy) {
    /// 不读取、不发送、不保存系统共享 Cookie，请求的安全默认值。
    XBHTTPCookiePolicyDisabled = 0,
    /// 使用当前应用的系统 CookieStorage，适用于服务端明确要求 Cookie 的接口。
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

/// 列表读请求的初始超时策略；与上传、登录等普通请求的默认配置相互独立。
FOUNDATION_EXPORT NSTimeInterval const XBHTTPListRequestTimeout;
FOUNDATION_EXPORT NSTimeInterval const XBHTTPListTotalTimeout;

/// 请求配置值对象。Query 与 Body 独立保存，参数位置不会随 GET/POST 自动变化。
@interface XBHTTPRequest : NSObject <NSCopying>

/// 接口的完整绝对地址，可以已经包含固定 Query；动态 Query 应放入 queryParameters。
@property (nonatomic, copy) NSString *URLString;
/// HTTP 动词只决定请求语义，不再隐式决定参数放在 URL 还是 Body。
@property (nonatomic, assign) XBHTTPMethod method;
/// 统一进行百分号编码并追加到 URL，适用于 GET，也支持 POST + Query 的接口。
@property (nonatomic, copy) NSDictionary<NSString *, id> *queryParameters;
/// 明确指定 Form、JSON、Raw Data 或 Multipart；默认不携带 Body。
@property (nonatomic, copy) XBHTTPBody *body;
/// 接口专属请求头。Body 的 Content-Type 由构建器统一管理；Disabled 模式下 Cookie 会被拦截。
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *headers;
/// 单个接口的超时时间；小于等于 0 时由构建器使用统一默认值。
@property (nonatomic, assign) NSTimeInterval timeout;
/// 整次传输的最长耗时，包含持续慢速接收；0 表示不额外限制，沿用系统行为。
@property (nonatomic, assign) NSTimeInterval totalTimeout;
/// 控制 NSURLRequest 的缓存读写策略，默认遵循系统协议缓存策略。
@property (nonatomic, assign) NSURLRequestCachePolicy cachePolicy;
/// 指定 公共参数不添加、放入 Query，或合并进 Body。
@property (nonatomic, assign) XBCommonParameterPlacement commonParameterPlacement;
/// Cookie 策略；默认为 Disabled。切换后由网络客户端选择对应的 Session。
@property (nonatomic, assign) XBHTTPCookiePolicy cookiePolicy;
/// 指定成功响应的解析方式，默认按 JSON 处理。
@property (nonatomic, assign) XBHTTPResponseType responseType;
/// 是否允许成功响应没有 Body；HEAD、204 或只依赖状态码的接口需要开启。
@property (nonatomic, assign) BOOL allowsEmptyResponse;
/// 接口认可的 HTTP 状态码，默认只接受 200～299。
@property (nonatomic, copy) NSIndexSet *acceptableStatusCodes;

/// 创建一份带安全默认值的请求描述，调用方再按接口协议配置 Query 和 Body。
+ (instancetype)requestWithURLString:(NSString *)URLString method:(XBHTTPMethod)method;

/// 创建列表读请求（含以 POST 查询的列表）：8 秒等待数据、10 秒传输总预算。
/// 参数位置仍由调用方按协议配置，发送入口仍为 XBNetwork。
+ (instancetype)listRequestWithURLString:(NSString *)URLString method:(XBHTTPMethod)method;

@end

NS_ASSUME_NONNULL_END
