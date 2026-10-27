//
//  XBHTTPResponseParser.m
//  XBNetwork
//

#import "XBHTTPResponseParser.h"
#import "XBNetworkError.h"

/// 错误响应和正常 JSON 响应使用同一套 Foundation 解码规则，避免两条解析实现逐渐产生差异。
static id XBJSONObjectFromData(NSData *data, NSError **error) {
    if (data.length == 0) {
        return nil;
    }
    return [NSJSONSerialization JSONObjectWithData:data
                                           options:(NSJSONReadingMutableContainers | NSJSONReadingAllowFragments)
                                             error:error];
}

@implementation XBHTTPResponseParser

/// 先验证 HTTP 状态及空响应规则，再按请求指定的格式解码数据。
- (XBHTTPResponse *)parseData:(NSData *)data
                     response:(NSURLResponse *)response
                   URLRequest:(NSURLRequest *)URLRequest
                      request:(XBHTTPRequest *)request
                     duration:(NSTimeInterval)duration
                        error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    if (![response isKindOfClass:NSHTTPURLResponse.class]) {
        [self assignError:error value:XBNetworkMakeError(XBNetworkErrorInvalidHTTPResponse,
                                                        @"服务器没有返回有效的 HTTP 响应",
                                                        URLRequest, nil, data, nil, nil)];
        return nil;
    }

    NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
    NSData *responseData = data ?: [NSData data];
    NSIndexSet *acceptableStatusCodes = request.acceptableStatusCodes;
    if (acceptableStatusCodes == nil) {
        acceptableStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    }
    if (![acceptableStatusCodes containsIndex:(NSUInteger)HTTPResponse.statusCode]) {
        id responseObject = XBJSONObjectFromData(responseData, nil);
        NSString *message = [NSString stringWithFormat:@"HTTP 请求失败（状态码 %ld）", (long)HTTPResponse.statusCode];
        [self assignError:error value:XBNetworkMakeError(XBNetworkErrorUnacceptableStatusCode,
                                                        message, URLRequest, HTTPResponse,
                                                        responseData, responseObject, nil)];
        return nil;
    }

    if (responseData.length == 0) {
        if (!request.allowsEmptyResponse) {
            [self assignError:error value:XBNetworkMakeError(XBNetworkErrorEmptyResponse,
                                                            @"服务器返回了空数据",
                                                            URLRequest, HTTPResponse,
                                                            responseData, nil, nil)];
            return nil;
        }
        return [[XBHTTPResponse alloc] initWithURLRequest:URLRequest
                                             HTTPResponse:HTTPResponse
                                                     data:responseData
                                           responseObject:nil
                                                 duration:duration];
    }

    NSError *decodingError = nil;
    id responseObject = [self responseObjectFromData:responseData request:request error:&decodingError];
    if (decodingError != nil) {
        [self assignError:error value:XBNetworkMakeError(XBNetworkErrorResponseDecodingFailed,
                                                        decodingError.localizedDescription ?: @"响应数据解析失败",
                                                        URLRequest, HTTPResponse,
                                                        responseData, nil, decodingError)];
        return nil;
    }
    return [[XBHTTPResponse alloc] initWithURLRequest:URLRequest
                                         HTTPResponse:HTTPResponse
                                                 data:responseData
                                       responseObject:responseObject
                                             duration:duration];
}

/// 按请求配置返回原始字节、UTF-8 文本或 JSON 对象。
- (id)responseObjectFromData:(NSData *)data
                      request:(XBHTTPRequest *)request
                        error:(NSError **)error {
    if (request.responseType == XBHTTPResponseTypeData) {
        return data;
    } else if (request.responseType == XBHTTPResponseTypeString) {
        NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (string == nil) {
            [self assignError:error value:[NSError errorWithDomain:XBNetworkErrorDomain
                                                              code:XBNetworkErrorResponseDecodingFailed
                                                          userInfo:@{NSLocalizedDescriptionKey: @"响应不是有效的 UTF-8 文本"}]];
        }
        return string;
    } else {
        return XBJSONObjectFromData(data, error);
    }
}

/// 兼容可为空的 NSError 输出参数。
- (BOOL)assignError:(NSError **)error value:(NSError *)value {
    if (error != NULL) {
        *error = value;
    }
    return NO;
}

@end
