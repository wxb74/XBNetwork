//
//  XBNetworkError.m
//  XBNetwork
//

#import "XBNetworkError.h"

NSString * const XBNetworkErrorDomain = @"XBNetworkErrorDomain";
NSString * const XBNetworkErrorRequestKey = @"XBNetworkErrorRequestKey";
NSString * const XBNetworkErrorResponseKey = @"XBNetworkErrorResponseKey";
NSString * const XBNetworkErrorResponseDataKey = @"XBNetworkErrorResponseDataKey";
NSString * const XBNetworkErrorResponseObjectKey = @"XBNetworkErrorResponseObjectKey";

// 底层错误可能有多层包装；限制遍历深度，兼容异常或循环的 underlyingError 链。
static BOOL XBNetworkErrorContains(NSError *error, BOOL (^matcher)(NSError *error), NSUInteger depth) {
    if (error == nil || depth > 8) {
        return NO;
    }
    if (matcher(error)) {
        return YES;
    }
    id underlyingObject = error.userInfo[NSUnderlyingErrorKey];
    if ([underlyingObject isKindOfClass:[NSError class]] && underlyingObject != error) {
        return XBNetworkErrorContains((NSError *)underlyingObject, matcher, depth + 1);
    }
    return NO;
}

/// 网络层错误可能被 NSURLSession、AFNetworking 或本层再次包装，统一沿 underlyingError 链匹配一组等价错误码。
static BOOL XBNetworkErrorMatchesCodes(NSError *error,
                                       XBNetworkErrorCode networkCode,
                                       NSInteger URLLoadingCode) {
    return XBNetworkErrorContains(error, ^BOOL(NSError *candidate) {
        if ([candidate.domain isEqualToString:XBNetworkErrorDomain]) {
            return candidate.code == networkCode;
        } else if ([candidate.domain isEqualToString:NSURLErrorDomain]) {
            return candidate.code == URLLoadingCode;
        } else {
            return NO;
        }
    }, 0);
}

BOOL XBNetworkErrorIsCancellation(NSError *error) {
    return XBNetworkErrorMatchesCodes(error, XBNetworkErrorCancelled, NSURLErrorCancelled);
}

BOOL XBNetworkErrorIsTimeout(NSError *error) {
    return XBNetworkErrorMatchesCodes(error, XBNetworkErrorTimedOut, NSURLErrorTimedOut);
}

BOOL XBNetworkErrorIsNotConnected(NSError *error) {
    return XBNetworkErrorMatchesCodes(error, XBNetworkErrorNotConnected, NSURLErrorNotConnectedToInternet);
}

NSString *XBNetworkErrorDisplayMessage(NSError *error, NSString *fallbackMessage) {
    if (error == nil) {
        return fallbackMessage.length > 0 ? fallbackMessage : @"网络请求失败";
    }
    if ([error.domain isEqualToString:XBNetworkErrorDomain] ||
        [error.domain isEqualToString:NSURLErrorDomain]) {
        NSString *message = error.localizedDescription;
        return message.length > 0 ? message : (fallbackMessage.length > 0 ? fallbackMessage : @"网络请求失败");
    }
    if (error.localizedDescription.length > 0) {
        return error.localizedDescription;
    }
    return fallbackMessage.length > 0 ? fallbackMessage : @"网络请求失败";
}

NSError *XBNetworkMakeError(XBNetworkErrorCode code,
                            NSString *message,
                            NSURLRequest *request,
                            NSHTTPURLResponse *response,
                            NSData *responseData,
                            id responseObject,
                            NSError *underlyingError) {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = message.length > 0 ? message : @"网络请求失败";
    if (request != nil) {
        userInfo[XBNetworkErrorRequestKey] = request;
        if (request.URL != nil) {
            userInfo[NSURLErrorFailingURLErrorKey] = request.URL;
        }
    }
    if (response != nil) {
        userInfo[XBNetworkErrorResponseKey] = response;
    }
    if (responseData != nil) {
        userInfo[XBNetworkErrorResponseDataKey] = responseData;
    }
    if (responseObject != nil) {
        userInfo[XBNetworkErrorResponseObjectKey] = responseObject;
    }
    if (underlyingError != nil) {
        userInfo[NSUnderlyingErrorKey] = underlyingError;
    }
    return [NSError errorWithDomain:XBNetworkErrorDomain code:code userInfo:userInfo];
}
