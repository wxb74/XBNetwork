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
