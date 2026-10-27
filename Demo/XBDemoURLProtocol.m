#import "XBDemoURLProtocol.h"
@interface XBDemoURLProtocol ()
@property (atomic) BOOL stopped;
@end
@implementation XBDemoURLProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return [request.URL.host isEqualToString:@"demo.xbnetwork.invalid"]; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    NSTimeInterval delay = [self.request.URL.path hasPrefix:@"/slow"] ? 0.3 : 0.01;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_global_queue(QOS_CLASS_DEFAULT,0), ^{
        @synchronized (self) {
            if (self.stopped) return;
            NSString *path = self.request.URL.path;
            if ([path isEqualToString:@"/offline"]) {
                [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]];
                return;
            }
            NSInteger status = [path hasPrefix:@"/status/"] ? path.lastPathComponent.integerValue : 200;
            NSData *body = self.request.HTTPBody;
            if (!body && self.request.HTTPBodyStream) {
                NSInputStream *stream = self.request.HTTPBodyStream; [stream open];
                NSMutableData *data = [NSMutableData data]; uint8_t buffer[4096]; NSInteger count;
                while ((count = [stream read:buffer maxLength:sizeof(buffer)]) > 0) [data appendBytes:buffer length:count];
                [stream close]; body = data;
            }
            NSDictionary *echo = @{ @"method":self.request.HTTPMethod ?: @"", @"URL":self.request.URL.absoluteString ?: @"", @"headers":self.request.allHTTPHeaderFields ?: @{}, @"body":[[NSString alloc] initWithData:body ?: [NSData data] encoding:NSUTF8StringEncoding] ?: @"", @"cookieHandling":@(self.request.HTTPShouldHandleCookies) };
            NSData *data = [NSJSONSerialization dataWithJSONObject:echo options:NSJSONWritingSortedKeys error:NULL];
            NSString *type = @"application/json";
            if ([path isEqualToString:@"/empty"]) { data = [NSData data]; status = 204; }
            if ([path isEqualToString:@"/text"]) { data = [@"Hello XBNetwork" dataUsingEncoding:NSUTF8StringEncoding]; type = @"text/plain"; }
            if ([path isEqualToString:@"/invalid"]) data = [@"not json" dataUsingEncoding:NSUTF8StringEncoding];
            if ([path isEqualToString:@"/binary"]) { const unsigned char bytes[] = {0,1,255}; data = [NSData dataWithBytes:bytes length:3]; type = @"application/octet-stream"; }
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":type,@"X-Demo":@"local-fixture"}];
            [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
            [self.client URLProtocol:self didLoadData:data];
            [self.client URLProtocolDidFinishLoading:self];
        }
    });
}
- (void)stopLoading { @synchronized (self) { self.stopped = YES; } }
@end
