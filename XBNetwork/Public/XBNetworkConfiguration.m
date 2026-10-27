#import "XBNetworkConfiguration.h"
@implementation XBNetworkConfiguration
- (instancetype)init {
    if ((self = [super init])) {
        _defaultHeaders = @{};
        _defaultTimeout = 20;
        _completionQueue = dispatch_get_main_queue();
        _sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    }
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    // 配置值和 Block 经属性复制；队列与 logger 保持同一引用，不会为每个请求另建日志器。
    // Block 捕获的宿主状态不会在这里冻结，动态公共参数仍可在每次请求时读取。
    XBNetworkConfiguration *copy = [[[self class] allocWithZone:zone] init];
    copy.defaultHeaders = self.defaultHeaders;
    copy.defaultTimeout = self.defaultTimeout;
    copy.completionQueue = self.completionQueue;
    copy.sessionConfiguration = self.sessionConfiguration;
    copy.commonParametersProvider = self.commonParametersProvider;
    copy.requestAdapter = self.requestAdapter;
    copy.logger = self.logger;
    return copy;
}
@end
