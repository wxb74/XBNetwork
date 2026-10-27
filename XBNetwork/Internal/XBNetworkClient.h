#import <Foundation/Foundation.h>
#import "../Public/XBNetworkConfiguration.h"
#import "../Public/XBHTTPResponse.h"
typedef void (^XBNetworkCompletion)(XBHTTPResponse * _Nullable response, NSError * _Nullable error);
typedef void (^XBNetworkUploadProgress)(NSProgress * _Nonnull progress);
NS_ASSUME_NONNULL_BEGIN
/// 内部传输实现，不作为业务调用入口。接收 XBNetwork 已合并公共参数和适配后的请求副本。
@interface XBNetworkClient : NSObject
/// 复制会话配置，创建 Cookie 禁用/启用两个独立会话，取消范围以此客户端为界。
- (instancetype)initWithConfiguration:(XBNetworkConfiguration *)configuration;
/// 同步构建请求并启动任务；进度、完成异步投递到 completionQueue，失败仍回调但可返回 nil。
- (nullable NSURLSessionTask *)performRequest:(XBHTTPRequest *)request uploadProgress:(nullable XBNetworkUploadProgress)progress completion:(nullable XBNetworkCompletion)completion;
/// 取消两个会话的当前任务，不关闭会话，不影响其他客户端。
- (void)cancelAllRequests;
/// 永久关闭会话；此后发送会通过完成回调报告取消错误。
- (void)invalidateAndCancel;
@end

NS_ASSUME_NONNULL_END
