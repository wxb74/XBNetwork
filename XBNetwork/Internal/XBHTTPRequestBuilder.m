//
//  XBHTTPRequestBuilder.m
//  XBNetwork
//

#import "XBHTTPRequestBuilder.h"
#import <AFNetworking/AFURLRequestSerialization.h>
#import <math.h>

NSString * const XBHTTPRequestBuilderErrorDomain = @"XBHTTPRequestBuilderErrorDomain";

@implementation XBHTTPRequestBuilder

/// 校验显式 Query/Body 与请求配置，再编码为可发送的 URLRequest。
- (NSMutableURLRequest *)buildURLRequestFromRequest:(XBHTTPRequest *)request
                                               error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    if (![request isKindOfClass:[XBHTTPRequest class]]) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorInvalidRequest
                  message:@"请求对象不能为空"];
        return nil;
    }
    if (request.method > XBHTTPMethodHEAD) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorInvalidRequest
                  message:@"HTTP Method 配置不合法"];
        return nil;
    }
    if (request.commonParameterPlacement > XBCommonParameterPlacementBody) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorInvalidRequest
                  message:@"公共参数位置配置不合法"];
        return nil;
    }
    if (request.commonParameterPlacement != XBCommonParameterPlacementNone) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorCommonParametersCannotMerge
                  message:@"公共参数必须先由 XBNetwork 转换为显式 Query 或 Body"];
        return nil;
    }
    if (request.cookiePolicy > XBHTTPCookiePolicySystem) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorInvalidRequest
                  message:@"Cookie 策略配置不合法"];
        return nil;
    }
    if (request.responseType > XBHTTPResponseTypeString) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorInvalidRequest
                  message:@"响应解析类型配置不合法"];
        return nil;
    }
    if (![request.URLString isKindOfClass:[NSString class]]) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorInvalidURL
                  message:@"请求 URL 必须是字符串"];
        return nil;
    }
    NSURL *URL = [NSURL URLWithString:request.URLString];
    if (request.URLString.length == 0 || URL == nil || (![URL.scheme.lowercaseString isEqualToString:@"http"] && ![URL.scheme.lowercaseString isEqualToString:@"https"]) || URL.host.length == 0) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorInvalidURL
                  message:@"请求 URL 不合法"];
        return nil;
    }

    if (request.queryParameters != nil && ![request.queryParameters isKindOfClass:[NSDictionary class]]) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorInvalidRequest
                  message:@"Query 参数必须是字典"];
        return nil;
    }
    if (request.acceptableStatusCodes != nil &&
        ![request.acceptableStatusCodes isKindOfClass:[NSIndexSet class]]) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorInvalidRequest
                  message:@"可接受状态码必须使用 NSIndexSet 配置"];
        return nil;
    }

    XBHTTPBody *body = request.body ?: [XBHTTPBody none];
    if (![body isKindOfClass:[XBHTTPBody class]] || body.type > XBHTTPBodyTypeMultipart) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorInvalidBody
                  message:@"Body 类型配置不合法"];
        return nil;
    }
    if ((body.type == XBHTTPBodyTypeForm || body.type == XBHTTPBodyTypeMultipart) &&
        body.parameters != nil &&
        ![body.parameters isKindOfClass:[NSDictionary class]]) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorInvalidBody
                  message:@"Form 和 Multipart 的普通参数必须是字典"];
        return nil;
    }
    if (body.type == XBHTTPBodyTypeMultipart && ![body.fileParts isKindOfClass:[NSArray class]]) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorInvalidBody
                  message:@"Multipart 文件必须使用数组配置"];
        return nil;
    }
    if ((request.method == XBHTTPMethodGET || request.method == XBHTTPMethodHEAD) &&
        body.type != XBHTTPBodyTypeNone) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorBodyNotAllowed
                  message:@"GET 和 HEAD 请求不允许携带 Body"];
        return nil;
    }

    NSDictionary<NSString *, id> *queryParameters = request.queryParameters ?: @{};
    XBHTTPBody *finalBody = body;

    NSString *URLString = [self URLStringByAppendingQueryParameters:queryParameters
                                                        URLString:request.URLString
                                                            error:error];
    if (URLString == nil) {
        return nil;
    }

    NSMutableURLRequest *URLRequest;
    if (finalBody.type == XBHTTPBodyTypeMultipart) {
        URLRequest = [self multipartRequestWithURLString:URLString
                                                 request:request
                                                    body:finalBody
                                                   error:error];
    } else {
        URLRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]
                                            cachePolicy:request.cachePolicy
                                        timeoutInterval:[self timeoutForRequest:request]];
        URLRequest.HTTPMethod = XBHTTPMethodString(request.method);
        if (![self applyBody:finalBody toURLRequest:URLRequest error:error]) {
            return nil;
        }
    }
    if (URLRequest == nil) {
        return nil;
    }

    [self applyDefaultHeadersToURLRequest:URLRequest];
    if (![self applyHeaders:request.headers
              cookiePolicy:request.cookiePolicy
              toURLRequest:URLRequest
                     error:error]) {
        return nil;
    }
    URLRequest.cachePolicy = request.cachePolicy;
    URLRequest.timeoutInterval = [self timeoutForRequest:request];
    if (request.cookiePolicy == XBHTTPCookiePolicyDisabled) {
        // 当前项目默认使用显式参数鉴权，禁止历史 Cookie 污染无 Cookie 协议接口并导致 400。
        URLRequest.HTTPShouldHandleCookies = NO;
        [URLRequest setValue:nil forHTTPHeaderField:@"Cookie"];
    } else {
        URLRequest.HTTPShouldHandleCookies = YES;
    }
    return URLRequest;
}

/// 沿用 AFNetworking 的 Query 编码规则，保持旧接口的参数字节格式。
- (NSString *)URLStringByAppendingQueryParameters:(NSDictionary<NSString *, id> *)queryParameters
                                        URLString:(NSString *)URLString
                                            error:(NSError **)error {
    if (queryParameters.count == 0) {
        return URLString;
    }
    NSError *serializationError = nil;
    NSMutableURLRequest *temporaryRequest = nil;
    @try {
        temporaryRequest = [[AFHTTPRequestSerializer serializer] requestWithMethod:@"GET"
                                                                          URLString:URLString
                                                                         parameters:queryParameters
                                                                              error:&serializationError];
    } @catch (NSException *exception) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorEncodingFailed
                  message:exception.reason ?: @"URL Query 参数编码异常"];
        return nil;
    }
    if (serializationError != nil || temporaryRequest.URL.absoluteString.length == 0) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorEncodingFailed
                  message:serializationError.localizedDescription ?: @"URL Query 参数编码失败"];
        return nil;
    }
    return temporaryRequest.URL.absoluteString;
}

/// 按 Body 类型编码表单、JSON 或原始字节；Multipart 由单独入口处理。
- (BOOL)applyBody:(XBHTTPBody *)body
     toURLRequest:(NSMutableURLRequest *)URLRequest
            error:(NSError **)error {
    if (body.type == XBHTTPBodyTypeNone) {
        return YES;
    } else if (body.type == XBHTTPBodyTypeForm) {
        NSError *serializationError = nil;
        NSMutableURLRequest *temporaryRequest = nil;
        @try {
            temporaryRequest = [[AFHTTPRequestSerializer serializer] requestWithMethod:@"POST"
                                                                              URLString:@"https://localhost/"
                                                                             parameters:body.parameters ?: @{}
                                                                                  error:&serializationError];
        } @catch (NSException *exception) {
            [self assignError:error
                         code:XBHTTPRequestBuilderErrorEncodingFailed
                      message:exception.reason ?: @"Form Body 编码异常"];
            return NO;
        }
        if (serializationError != nil) {
            [self assignError:error
                         code:XBHTTPRequestBuilderErrorEncodingFailed
                      message:serializationError.localizedDescription ?: @"Form Body 编码失败"];
            return NO;
        }
        URLRequest.HTTPBody = temporaryRequest.HTTPBody;
        [URLRequest setValue:[temporaryRequest valueForHTTPHeaderField:@"Content-Type"]
          forHTTPHeaderField:@"Content-Type"];
        return YES;
    } else if (body.type == XBHTTPBodyTypeJSON) {
        id JSONObject = body.JSONObject;
        if (JSONObject == nil || ![NSJSONSerialization isValidJSONObject:JSONObject]) {
            [self assignError:error
                         code:XBHTTPRequestBuilderErrorInvalidBody
                      message:@"JSON Body 不是合法的 JSON 对象"];
            return NO;
        }
        NSError *serializationError = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:JSONObject options:0 error:&serializationError];
        if (serializationError != nil || data == nil) {
            [self assignError:error
                         code:XBHTTPRequestBuilderErrorEncodingFailed
                      message:serializationError.localizedDescription ?: @"JSON Body 编码失败"];
            return NO;
        }
        URLRequest.HTTPBody = data;
        [URLRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        return YES;
    } else if (body.type == XBHTTPBodyTypeRawData) {
        if (![body.rawData isKindOfClass:[NSData class]] ||
            ![body.contentType isKindOfClass:[NSString class]] ||
            body.contentType.length == 0) {
            [self assignError:error
                         code:XBHTTPRequestBuilderErrorInvalidBody
                      message:@"Raw Body 必须同时提供数据和 Content-Type"];
            return NO;
        }
        URLRequest.HTTPBody = body.rawData;
        @try {
            [URLRequest setValue:body.contentType forHTTPHeaderField:@"Content-Type"];
        } @catch (NSException *exception) {
            [self assignError:error
                         code:XBHTTPRequestBuilderErrorInvalidBody
                      message:exception.reason ?: @"Raw Body 的 Content-Type 不合法"];
            return NO;
        }
        return YES;
    }

    [self assignError:error
                 code:XBHTTPRequestBuilderErrorInvalidBody
              message:@"当前 Body 类型无法由普通请求构建器处理"];
    return NO;
}

/// 先校验文件字段，再沿用 AFNetworking 的 multipart 编码方式。
- (NSMutableURLRequest *)multipartRequestWithURLString:(NSString *)URLString
                                               request:(XBHTTPRequest *)request
                                                  body:(XBHTTPBody *)body
                                                 error:(NSError **)error {
    for (id partObject in body.fileParts) {
        if (![partObject isKindOfClass:[XBHTTPFilePart class]]) {
            [self assignError:error
                         code:XBHTTPRequestBuilderErrorInvalidBody
                      message:@"Multipart 文件列表包含非法对象"];
            return nil;
        }
        XBHTTPFilePart *part = (XBHTTPFilePart *)partObject;
        if (![part.name isKindOfClass:[NSString class]] ||
            ![part.fileName isKindOfClass:[NSString class]] ||
            (part.MIMEType != nil && ![part.MIMEType isKindOfClass:[NSString class]]) ||
            ![part.data isKindOfClass:[NSData class]] ||
            part.name.length == 0 ||
            part.fileName.length == 0) {
            [self assignError:error
                         code:XBHTTPRequestBuilderErrorInvalidBody
                      message:@"Multipart 文件字段必须提供字段名、文件名和文件数据"];
            return nil;
        }
    }

    NSError *serializationError = nil;
    NSMutableURLRequest *URLRequest = nil;
    @try {
        URLRequest = [[AFHTTPRequestSerializer serializer]
            multipartFormRequestWithMethod:XBHTTPMethodString(request.method)
            URLString:URLString
            parameters:body.parameters
            constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                for (XBHTTPFilePart *part in body.fileParts) {
                    // 保留调用方明确指定的 MIME Type。
                    NSString *MIMEType = part.MIMEType ?: @"";
                    [formData appendPartWithFileData:part.data
                                               name:part.name
                                           fileName:part.fileName
                                           mimeType:MIMEType];
                }
            }
            error:&serializationError];
    } @catch (NSException *exception) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorEncodingFailed
                  message:exception.reason ?: @"Multipart Body 编码异常"];
        return nil;
    }
    if (serializationError != nil || URLRequest == nil) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorEncodingFailed
                  message:serializationError.localizedDescription ?: @"Multipart Body 编码失败"];
        return nil;
    }
    return URLRequest;
}

/// 用户头可覆盖默认值，但不能重新注入禁用的 Cookie 或破坏生成的 Content-Type。
- (BOOL)applyHeaders:(NSDictionary<NSString *, NSString *> *)headers
        cookiePolicy:(XBHTTPCookiePolicy)cookiePolicy
        toURLRequest:(NSMutableURLRequest *)URLRequest
               error:(NSError **)error {
    if (headers != nil && ![headers isKindOfClass:[NSDictionary class]]) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorInvalidRequest
                  message:@"请求头必须是字典"];
        return NO;
    }

    __block BOOL isValid = YES;
    [headers enumerateKeysAndObjectsUsingBlock:^(id keyObject, id valueObject, BOOL *stop) {
        if (![keyObject isKindOfClass:[NSString class]] ||
            ![valueObject isKindOfClass:[NSString class]] ||
            [(NSString *)keyObject length] == 0) {
            isValid = NO;
            *stop = YES;
            return;
        }
        NSString *key = (NSString *)keyObject;
        NSString *value = (NSString *)valueObject;
        BOOL isCookieHeader = [key caseInsensitiveCompare:@"Cookie"] == NSOrderedSame;
        BOOL isGeneratedContentType = ([key caseInsensitiveCompare:@"Content-Type"] == NSOrderedSame &&
                                       [URLRequest valueForHTTPHeaderField:@"Content-Type"].length > 0);
        if (isCookieHeader && cookiePolicy == XBHTTPCookiePolicyDisabled) {
            return;
        } else if (isGeneratedContentType) {
            return;
        } else {
            @try {
                [URLRequest setValue:value forHTTPHeaderField:key];
            } @catch (__unused NSException *exception) {
                isValid = NO;
                *stop = YES;
            }
        }
    }];
    if (!isValid) {
        [self assignError:error
                     code:XBHTTPRequestBuilderErrorInvalidRequest
                  message:@"请求头的键和值必须是有效字符串"];
        return NO;
    }
    return YES;
}

/// 保留旧 AFNetworking 请求的 Accept-Language 和 User-Agent 默认值；
/// 业务 headers 在其后应用，仍可按单个接口覆盖。
- (void)applyDefaultHeadersToURLRequest:(NSMutableURLRequest *)URLRequest {
    static NSDictionary<NSString *, NSString *> *defaultHeaders = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultHeaders = [[[AFHTTPRequestSerializer serializer] HTTPRequestHeaders] copy] ?: @{};
    });
    [defaultHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        (void)stop;
        if ([URLRequest valueForHTTPHeaderField:key].length == 0) {
            [URLRequest setValue:value forHTTPHeaderField:key];
        }
    }];
}

/// 非有限值或非正超时统一回退到 20 秒。
- (NSTimeInterval)timeoutForRequest:(XBHTTPRequest *)request {
    if (isfinite(request.timeout) && request.timeout > 0) {
        return request.timeout;
    }
    return 20.0;
}

/// 请求构建失败统一转换为 Builder 域错误，供上层包装网络错误。
- (BOOL)assignError:(NSError **)error
               code:(XBHTTPRequestBuilderErrorCode)code
            message:(NSString *)message {
    if (error != NULL) {
        *error = [NSError errorWithDomain:XBHTTPRequestBuilderErrorDomain
                                     code:code
                                 userInfo:@{NSLocalizedDescriptionKey: message ?: @"请求构建失败"}];
    }
    return NO;
}

@end
