#import <Foundation/Foundation.h>
#import "XBHTTPRequest.h"
#import "XBNetworkLogger.h"
NS_ASSUME_NONNULL_BEGIN
/// Called for requests opting into Query/Body placement. Request fields override common fields.
typedef NSDictionary<NSString *, id> * _Nonnull (^XBNetworkCommonParametersProvider)(XBHTTPRequest *request);
/// Runs synchronously on a private snapshot before building. Return NO with an error to reject.
typedef BOOL (^XBNetworkRequestAdapter)(XBHTTPRequest *request, NSError * _Nullable * _Nullable error);
@interface XBNetworkConfiguration : NSObject <NSCopying>
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *defaultHeaders;
@property (nonatomic) NSTimeInterval defaultTimeout;
/// Main queue by default. Prefer a serial queue for predictable callback ordering.
@property (nonatomic, strong) dispatch_queue_t completionQueue;
/// Copied on initialization. Supports URLCache, protocolClasses and ordinary URLSession settings.
/// Cookie policy is controlled separately by each request.
@property (nonatomic, copy) NSURLSessionConfiguration *sessionConfiguration;
@property (nonatomic, copy, nullable) XBNetworkCommonParametersProvider commonParametersProvider;
@property (nonatomic, copy, nullable) XBNetworkRequestAdapter requestAdapter;
@property (nonatomic, strong, nullable) id<XBNetworkLogger> logger;
@end
NS_ASSUME_NONNULL_END
