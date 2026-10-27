//
//  XBHTTPRequest.m
//  XBNetwork
//

#import "XBHTTPRequest.h"

NSTimeInterval const XBHTTPListRequestTimeout = 8.0;
NSTimeInterval const XBHTTPListTotalTimeout = 10.0;

/// 将请求枚举映射为 HTTP 协议方法名。
NSString *XBHTTPMethodString(XBHTTPMethod method) {
    switch (method) {
        case XBHTTPMethodGET:
            return @"GET";
        case XBHTTPMethodPOST:
            return @"POST";
        case XBHTTPMethodPUT:
            return @"PUT";
        case XBHTTPMethodPATCH:
            return @"PATCH";
        case XBHTTPMethodDELETE:
            return @"DELETE";
        case XBHTTPMethodHEAD:
            return @"HEAD";
    }
    return @"GET";
}

@implementation XBHTTPRequest

/// 只对显式选择列表策略的请求缩短超时，不根据 URL 或 HTTP 动词猜测用途。
+ (instancetype)listRequestWithURLString:(NSString *)URLString method:(XBHTTPMethod)method {
    XBHTTPRequest *request = [self requestWithURLString:URLString method:method];
    request.timeout = XBHTTPListRequestTimeout;
    request.totalTimeout = XBHTTPListTotalTimeout;
    return request;
}

/// 以 URL 和方法创建请求，其余配置沿用默认值。
+ (instancetype)requestWithURLString:(NSString *)URLString method:(XBHTTPMethod)method {
    XBHTTPRequest *request = [[self alloc] init];
    request.URLString = URLString;
    request.method = method;
    return request;
}

/// 默认禁用 Cookie、解析 JSON 并只接受 2xx 状态码。
- (instancetype)init {
    self = [super init];
    if (self) {
        _URLString = @"";
        _method = XBHTTPMethodGET;
        _queryParameters = @{};
        _body = [XBHTTPBody none];
        _headers = @{};
        _timeout = 0; // 使用客户端配置的默认超时。
        _cachePolicy = NSURLRequestUseProtocolCachePolicy;
        _commonParameterPlacement = XBCommonParameterPlacementNone;
        _cookiePolicy = XBHTTPCookiePolicyDisabled;
        _responseType = XBHTTPResponseTypeJSON;
        _allowsEmptyResponse = NO;
        _acceptableStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    }
    return self;
}

/// 发送前复制完整配置，避免异步任务观察到业务侧的后续修改。
- (id)copyWithZone:(NSZone *)zone {
    XBHTTPRequest *request = [[XBHTTPRequest alloc] init];
    request.URLString = self.URLString;
    request.method = self.method;
    request.queryParameters = self.queryParameters;
    request.body = self.body;
    request.headers = self.headers;
    request.timeout = self.timeout;
    request.totalTimeout = self.totalTimeout;
    request.cachePolicy = self.cachePolicy;
    request.commonParameterPlacement = self.commonParameterPlacement;
    request.cookiePolicy = self.cookiePolicy;
    request.responseType = self.responseType;
    request.allowsEmptyResponse = self.allowsEmptyResponse;
    request.acceptableStatusCodes = self.acceptableStatusCodes;
    return request;
}

@end
