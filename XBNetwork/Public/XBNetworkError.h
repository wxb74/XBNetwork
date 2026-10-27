//
//  XBNetworkError.h
//  XBNetwork
//
//  为构建、传输、HTTP 状态和响应解析提供稳定的错误分类。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const XBNetworkErrorDomain;
FOUNDATION_EXPORT NSString * const XBNetworkErrorRequestKey;
FOUNDATION_EXPORT NSString * const XBNetworkErrorResponseKey;
FOUNDATION_EXPORT NSString * const XBNetworkErrorResponseDataKey;
FOUNDATION_EXPORT NSString * const XBNetworkErrorResponseObjectKey;

typedef NS_ENUM(NSInteger, XBNetworkErrorCode) {
    XBNetworkErrorRequestBuildFailed = 1,
    XBNetworkErrorTransportFailed,
    XBNetworkErrorCancelled,
    XBNetworkErrorTimedOut,
    XBNetworkErrorNotConnected,
    XBNetworkErrorInvalidHTTPResponse,
    XBNetworkErrorUnacceptableStatusCode,
    XBNetworkErrorEmptyResponse,
    XBNetworkErrorResponseDecodingFailed
};

/// 创建结构一致的网络错误；所有附加对象都经过空值检查，不会向 userInfo 写入 nil。
FOUNDATION_EXPORT NSError *XBNetworkMakeError(XBNetworkErrorCode code,
                                              NSString *message,
                                              NSURLRequest * _Nullable request,
                                              NSHTTPURLResponse * _Nullable response,
                                              NSData * _Nullable responseData,
                                              id _Nullable responseObject,
                                              NSError * _Nullable underlyingError);

/// 同时识别新网络层取消错误和底层 NSURLErrorCancelled，供页面静默结束主动取消的请求。
FOUNDATION_EXPORT BOOL XBNetworkErrorIsCancellation(NSError * _Nullable error);

/// 识别网络层包装后的超时错误和底层 NSURLErrorTimedOut，供日志和页面统一判断。
FOUNDATION_EXPORT BOOL XBNetworkErrorIsTimeout(NSError * _Nullable error);

/// 识别网络层包装后的断网错误和底层 NSURLErrorNotConnectedToInternet。
FOUNDATION_EXPORT BOOL XBNetworkErrorIsNotConnected(NSError * _Nullable error);

/// 获取可直接展示的错误文案。新网络错误使用 localizedDescription，
/// 其他错误优先使用 localizedDescription。
FOUNDATION_EXPORT NSString *XBNetworkErrorDisplayMessage(NSError * _Nullable error,
                                                         NSString *fallbackMessage);

NS_ASSUME_NONNULL_END
