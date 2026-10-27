#import "XBNetworkClient.h"
#import "XBHTTPRequestBuilder.h"
#import "XBHTTPResponseParser.h"
#import "XBNetworkError.h"
#import <math.h>

// NSURLSession 强持有 delegate；代理弱引用客户端，打断 Session → Client → Session 循环。
@interface XBNetworkDelegateProxy : NSObject <NSURLSessionTaskDelegate>
@property (nonatomic, weak) id<NSURLSessionTaskDelegate> target;
@end
@implementation XBNetworkDelegateProxy
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    [self.target URLSession:session task:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalBytesExpectedToSend];
}
@end

// 每个请求各自持有完成状态和总超时计时器；所有竞争结果必须通过同一个 finish 门。
@interface XBNetworkRequestState : NSObject
@property (nonatomic) BOOL completed;
@property (nonatomic, strong) dispatch_source_t timer;
@end
@implementation XBNetworkRequestState
@end

@interface XBNetworkClient () <NSURLSessionTaskDelegate>
@property (nonatomic, copy) XBNetworkConfiguration *configuration;
@property (nonatomic, strong) NSURLSession *cookieDisabledSession;
@property (nonatomic, strong) NSURLSession *systemCookieSession;
@property (nonatomic, strong) NSMutableDictionary<NSString *, XBNetworkUploadProgress> *progressHandlers;
@property (nonatomic, strong) XBNetworkDelegateProxy *delegateProxy;
@property (nonatomic) BOOL invalidated;
@end

@implementation XBNetworkClient
- (instancetype)initWithConfiguration:(XBNetworkConfiguration *)configuration {
    if ((self = [super init])) {
        _configuration = [configuration copy];
        _progressHandlers = [NSMutableDictionary dictionary];
        _delegateProxy = [XBNetworkDelegateProxy new];
        _delegateProxy.target = self;
        // 仅关闭 NSURLRequest 的 Cookie 开关不足以隔离存储，因此使用无 CookieStorage 的独立会话。
        NSURLSessionConfiguration *disabled = [configuration.sessionConfiguration copy] ?: [NSURLSessionConfiguration defaultSessionConfiguration];
        disabled.HTTPShouldSetCookies = NO;
        disabled.HTTPCookieStorage = nil;
        _cookieDisabledSession = [NSURLSession sessionWithConfiguration:disabled delegate:_delegateProxy delegateQueue:nil];
        NSURLSessionConfiguration *system = [configuration.sessionConfiguration copy] ?: [NSURLSessionConfiguration defaultSessionConfiguration];
        system.HTTPShouldSetCookies = YES;
        system.HTTPCookieStorage = configuration.sessionConfiguration.HTTPCookieStorage ?: NSHTTPCookieStorage.sharedHTTPCookieStorage;
        _systemCookieSession = [NSURLSession sessionWithConfiguration:system delegate:_delegateProxy delegateQueue:nil];
    }
    return self;
}
/// 只构造脱敏元数据，不读取 HTTPBodyStream；日志接收者异常不影响传输和完成回调。
- (void)recordRequest:(NSURLRequest *)request response:(XBHTTPResponse *)response error:(NSError *)error phase:(NSString *)phase {
    id<XBNetworkLogger> logger = self.configuration.logger;
    if (!logger) return;
    @try {
        NSURLComponents *URL = [NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
        URL.user = nil; URL.password = nil; URL.fragment = nil;
        NSMutableArray *items = [NSMutableArray array];
        for (NSURLQueryItem *item in URL.queryItems) [items addObject:[NSURLQueryItem queryItemWithName:item.name value:@"[REDACTED]"]];
        if (URL.queryItems) URL.queryItems = items;
        NSMutableDictionary *headers = [NSMutableDictionary dictionary];
        for (NSString *key in request.allHTTPHeaderFields) headers[key] = @"[REDACTED]";
        NSDictionary *event = @{ @"phase":phase, @"method":request.HTTPMethod ?: @"", @"URL":URL.string ?: @"", @"headers":[headers copy], @"statusCode":@(response.HTTPResponse.statusCode), @"duration":@(response.duration), @"errorCode":@(error.code) };
        [logger networkDidRecordEvent:event];
    } @catch (__unused NSException *exception) { }
}
- (NSURLSessionTask *)performRequest:(XBHTTPRequest *)request uploadProgress:(XBNetworkUploadProgress)progress completion:(XBNetworkCompletion)completion {
    // 解析使用同一个快照，避免发送后外部修改 responseType、空响应规则等影响正在执行的任务。
    XBHTTPRequest *snapshot = [request copy];
    NSError *buildError = nil;
    NSURLRequest *URLRequest = [[XBHTTPRequestBuilder new] buildURLRequestFromRequest:snapshot error:&buildError];
    if (!URLRequest) {
        NSError *error = XBNetworkMakeError(XBNetworkErrorRequestBuildFailed, buildError.localizedDescription ?: @"Request build failed",nil,nil,nil,nil,buildError);
        [self recordRequest:nil response:nil error:error phase:@"completed"];
        [self complete:completion response:nil error:error];
        return nil;
    }
    XBNetworkRequestState *state = [XBNetworkRequestState new];
    // 总超时、取消和传输完成可能同时到达：只接纳第一个结果，并取消计时器防止重复交付。
    BOOL (^finish)(XBHTTPResponse *, NSError *) = ^BOOL(XBHTTPResponse *response, NSError *error) {
        @synchronized (state) {
            if (state.completed) return NO;
            state.completed = YES;
            if (state.timer) { dispatch_source_cancel(state.timer); state.timer = nil; }
        }
        [self recordRequest:URLRequest response:response error:error phase:@"completed"];
        [self complete:completion response:response error:error];
        return YES;
    };
    NSURLSession *session = snapshot.cookiePolicy == XBHTTPCookiePolicySystem ? self.systemCookieSession : self.cookieDisabledSession;
    NSTimeInterval start = NSProcessInfo.processInfo.systemUptime;
    __block __weak NSURLSessionDataTask *weakTask;
    NSURLSessionDataTask *task;
    @synchronized (self) {
        if (self.invalidated) {
            finish(nil, XBNetworkMakeError(XBNetworkErrorCancelled,@"Client is closed",URLRequest,nil,nil,nil,nil));
            return nil;
        }
        task = [session dataTaskWithRequest:URLRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *transportError) {
            @synchronized (self.progressHandlers) { [self.progressHandlers removeObjectForKey:[self keyForSession:session task:weakTask]]; }
            @synchronized (state) { if (state.completed) return; }
            if (transportError) {
                XBNetworkErrorCode code = XBNetworkErrorIsCancellation(transportError) ? XBNetworkErrorCancelled : XBNetworkErrorIsTimeout(transportError) ? XBNetworkErrorTimedOut : XBNetworkErrorIsNotConnected(transportError) ? XBNetworkErrorNotConnected : XBNetworkErrorTransportFailed;
                finish(nil, XBNetworkMakeError(code,transportError.localizedDescription,URLRequest,[response isKindOfClass:NSHTTPURLResponse.class] ? (id)response : nil,data,nil,transportError));
                return;
            }
            NSError *error = nil;
            XBHTTPResponse *parsed = [[XBHTTPResponseParser new] parseData:data response:response URLRequest:URLRequest request:snapshot duration:MAX(0,NSProcessInfo.processInfo.systemUptime-start) error:&error];
            finish(parsed,error);
        }];
        weakTask = task;
        if (progress) {
            // 进度投递到业务队列后可能已经过时，真正执行前再检查一次完成状态。
            @synchronized (self.progressHandlers) {
                self.progressHandlers[[self keyForSession:session task:task]] = ^(NSProgress *value) {
                    @synchronized (state) { if (state.completed) return; }
                    progress(value);
                };
            }
        }
        // 总预算独立于系统等待数据超时；换算纳秒时限幅，防止 dispatch_time 的有符号整数溢出。
        if (isfinite(snapshot.totalTimeout) && snapshot.totalTimeout > 0) {
            state.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_global_queue(QOS_CLASS_UTILITY,0));
            int64_t ns = (int64_t)(MIN(snapshot.totalTimeout, (double)INT64_MAX / NSEC_PER_SEC / 2) * NSEC_PER_SEC);
            dispatch_source_set_timer(state.timer,dispatch_time(DISPATCH_TIME_NOW,ns),DISPATCH_TIME_FOREVER,NSEC_PER_MSEC);
            dispatch_source_set_event_handler(state.timer, ^{
                NSError *underlying = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
                if (finish(nil,XBNetworkMakeError(XBNetworkErrorTimedOut,@"Request total timeout exceeded",URLRequest,nil,nil,nil,underlying))) [weakTask cancel];
            });
            dispatch_resume(state.timer);
        }
        [self recordRequest:URLRequest response:nil error:nil phase:@"started"];
        [task resume];
    }
    return task;
}
// 不同会话的 taskIdentifier 可重复，以会话地址和任务标识共同区分上传回调。
- (NSString *)keyForSession:(NSURLSession *)session task:(NSURLSessionTask *)task { return [NSString stringWithFormat:@"%p-%lu",session,(unsigned long)task.taskIdentifier]; }
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)sent totalBytesExpectedToSend:(int64_t)expected {
    XBNetworkUploadProgress progress;
    @synchronized (self.progressHandlers) { progress = self.progressHandlers[[self keyForSession:session task:task]]; }
    if (!progress) return;
    NSProgress *value = [NSProgress progressWithTotalUnitCount:expected > 0 ? expected : -1];
    value.completedUnitCount = expected > 0 ? MIN(sent,expected) : sent;
    dispatch_async(self.configuration.completionQueue, ^{ progress(value); });
}
/// 所有完成结果（含本地构建失败）统一异步交付，不在 NSURLSession 线程执行宿主 UI 逻辑。
- (void)complete:(XBNetworkCompletion)completion response:(XBHTTPResponse *)response error:(NSError *)error {
    if (completion) dispatch_async(self.configuration.completionQueue, ^{ completion(response,error); });
}
- (void)cancelAllRequests {
    for (NSURLSession *session in @[self.cookieDisabledSession,self.systemCookieSession]) {
        [session getAllTasksWithCompletionHandler:^(NSArray<NSURLSessionTask *> *tasks) { for (NSURLSessionTask *task in tasks) [task cancel]; }];
    }
}
- (void)invalidateAndCancel {
    @synchronized (self) {
        if (self.invalidated) return;
        self.invalidated = YES;
        [self.cookieDisabledSession invalidateAndCancel];
        [self.systemCookieSession invalidateAndCancel];
    }
}
- (void)dealloc { [self.cookieDisabledSession invalidateAndCancel]; [self.systemCookieSession invalidateAndCancel]; }
@end
