#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/**
 可选的请求事件接收协议；设置 configuration.logger 后才启用，组件不直接打印日志。

 回调可能来自调用线程或会话线程，不使用 completionQueue。实现应线程安全且快速返回，
 较重的格式化、磁盘写入请自行投递到串行队列。接收者抛出的 Objective-C 异常会被隔离。

 事件不包含 Body：移除 URL 用户名、密码、Fragment，并将所有 Query 值及请求头值替换为
 [REDACTED]。URL 路径和字段名仍可见，宿主应按业务需要继续过滤。
 此公开版本的日志回调不受 DEBUG 宏限制；Release 需要关闭时不要配置 logger。
 */
@protocol XBNetworkLogger <NSObject>
/**
 接收一次开始或结束事件。event 字段如下：
 - phase：NSString，started 表示即将启动任务，completed 表示请求结束或构建失败。
 - method、URL：NSString，请求方法和脱敏后的 URL；无法构建请求时可能为空串。
 - headers：NSDictionary，字段名保留、值全部脱敏。
 - statusCode、duration：NSNumber，成功解析响应的 HTTP 状态码和耗时（秒）；无响应对象时为 0。
 - errorCode：NSNumber，XBNetworkErrorCode；成功或开始事件为 0。

 失败不一定先收到 started，例如构建失败只产生 completed。Provider/Adapter 在编码前
 拒绝请求时，本版本不产生事件。事件没有请求唯一标识，不应仅靠事件顺序匹配并发请求。
 */
- (void)networkDidRecordEvent:(NSDictionary<NSString *, id> *)event;
@end
NS_ASSUME_NONNULL_END
