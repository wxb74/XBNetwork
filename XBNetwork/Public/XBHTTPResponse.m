//
//  XBHTTPResponse.m
//  XBNetwork
//

#import "XBHTTPResponse.h"

@implementation XBHTTPResponse

/// 将请求、HTTP 元数据、原始字节及解析结果组成同一次请求的响应快照。
- (instancetype)initWithURLRequest:(NSURLRequest *)URLRequest
                       HTTPResponse:(NSHTTPURLResponse *)HTTPResponse
                               data:(NSData *)data
                     responseObject:(id)responseObject
                           duration:(NSTimeInterval)duration {
    self = [super init];
    if (self) {
        _URLRequest = [URLRequest copy];
        _HTTPResponse = HTTPResponse;
        _data = [data copy];
        _responseObject = responseObject;
        _duration = duration;
    }
    return self;
}

@end
