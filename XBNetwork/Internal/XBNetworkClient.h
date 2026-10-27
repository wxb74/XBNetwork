#import <Foundation/Foundation.h>
#import "../Public/XBNetworkConfiguration.h"
#import "../Public/XBHTTPResponse.h"
typedef void (^XBNetworkCompletion)(XBHTTPResponse * _Nullable response, NSError * _Nullable error);
typedef void (^XBNetworkUploadProgress)(NSProgress * _Nonnull progress);
NS_ASSUME_NONNULL_BEGIN
@interface XBNetworkClient : NSObject
- (instancetype)initWithConfiguration:(XBNetworkConfiguration *)configuration;
- (nullable NSURLSessionTask *)performRequest:(XBHTTPRequest *)request uploadProgress:(nullable XBNetworkUploadProgress)progress completion:(nullable XBNetworkCompletion)completion;
- (void)cancelAllRequests;
- (void)invalidateAndCancel;
@end

NS_ASSUME_NONNULL_END
