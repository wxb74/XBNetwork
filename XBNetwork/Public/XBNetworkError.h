//
//  XBNetworkError.h
//  XBNetwork
//
//  为构建、传输、HTTP 状态和响应解析提供稳定的错误分类。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 组件构建、传输及解析错误统一使用的 NSError.domain；业务接口的自定义 code 不在此定义。
FOUNDATION_EXPORT NSString * const XBNetworkErrorDomain;
/// userInfo 中的 NSURLRequest：实际编码后的请求，构建阶段失败时可能不存在。
FOUNDATION_EXPORT NSString * const XBNetworkErrorRequestKey;
/// userInfo 中的 NSHTTPURLResponse：可读取 statusCode 和 allHeaderFields。
FOUNDATION_EXPORT NSString * const XBNetworkErrorResponseKey;
/// userInfo 中的 NSData：原始响应字节；可能为空数据或不存在。
FOUNDATION_EXPORT NSString * const XBNetworkErrorResponseDataKey;
/// userInfo 中的 JSON 对象：HTTP 状态码不被接受且响应可解析为 JSON 时提供。
/// 上述对象均为原始数据，未做日志脱敏；使用前检查类型与是否存在。
FOUNDATION_EXPORT NSString * const XBNetworkErrorResponseObjectKey;

/// 先检查 error.domain，再按此枚举判断原因；取消、超时、断网也可直接使用下方辅助函数。
typedef NS_ENUM(NSInteger, XBNetworkErrorCode) {
    /// URL、参数、Body、配置不合法，或请求适配器拒绝发送；通常没有创建任务。
    XBNetworkErrorRequestBuildFailed = 1,
    /// 其他 NSURLSession 传输错误，例如连接失败或 TLS 错误；底层错误见 NSUnderlyingErrorKey。
    XBNetworkErrorTransportFailed,
    /// 主动取消任务、关闭实例，或底层返回 NSURLErrorCancelled。
    XBNetworkErrorCancelled,
    /// 等待数据超时，或整次传输超过 totalTimeout。
    XBNetworkErrorTimedOut,
    /// 底层返回 NSURLErrorNotConnectedToInternet；不代表能够识别所有网络不可达情况。
    XBNetworkErrorNotConnected,
    /// 收到的响应不是 NSHTTPURLResponse。
    XBNetworkErrorInvalidHTTPResponse,
    /// HTTP 状态码不在 acceptableStatusCodes 中，例如默认规则下的 401 或 500。
    XBNetworkErrorUnacceptableStatusCode,
    /// 响应没有数据且 allowsEmptyResponse 为 NO；204、HEAD 也不会自动豁免。
    XBNetworkErrorEmptyResponse,
    /// 响应无法按指定格式解码，例如非法 JSON 或非 UTF-8 文本。
    XBNetworkErrorResponseDecodingFailed
};

/// 创建结构一致的网络错误；所有附加对象都经过空值检查，不会向 userInfo 写入 nil。
/// 通常由组件内部调用；底层原因保存在 NSUnderlyingErrorKey，message 为空时使用默认提示。
FOUNDATION_EXPORT NSError *XBNetworkMakeError(XBNetworkErrorCode code,
                                              NSString *message,
                                              NSURLRequest * _Nullable request,
                                              NSHTTPURLResponse * _Nullable response,
                                              NSData * _Nullable responseData,
                                              id _Nullable responseObject,
                                              NSError * _Nullable underlyingError);

/// 识别组件取消错误及 NSURLErrorCancelled，并沿底层错误链查找；传 nil 返回 NO。
/// 页面主动取消后通常可静默结束，避免向用户提示“请求失败”。
FOUNDATION_EXPORT BOOL XBNetworkErrorIsCancellation(NSError * _Nullable error);

/// 识别组件超时错误及 NSURLErrorTimedOut，含底层错误链；传 nil 返回 NO。
FOUNDATION_EXPORT BOOL XBNetworkErrorIsTimeout(NSError * _Nullable error);

/// 识别组件断网错误及 NSURLErrorNotConnectedToInternet，含底层错误链；传 nil 返回 NO。
FOUNDATION_EXPORT BOOL XBNetworkErrorIsNotConnected(NSError * _Nullable error);

/// 优先返回 error.localizedDescription；无可用文案时用 fallbackMessage，再回退到“网络请求失败”。
/// 不翻译底层系统文案，也不读取服务端业务 message；宿主有统一提示规范时请自行映射。
FOUNDATION_EXPORT NSString *XBNetworkErrorDisplayMessage(NSError * _Nullable error,
                                                         NSString *fallbackMessage);

NS_ASSUME_NONNULL_END
