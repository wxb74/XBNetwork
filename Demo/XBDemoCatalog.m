#import "XBDemoCatalog.h"
@implementation XBDemoCatalog
+ (NSArray<NSString *> *)titles { return @[@"GET 与自定义 Header",@"POST Form",@"POST JSON",@"Query + JSON",@"Query + Form",@"PUT / PATCH / DELETE / HEAD",@"Raw Data",@"Multipart 上传",@"文本与二进制响应",@"HTTP 错误与解析失败",@"空响应",@"总耗时超时",@"主动取消",@"Cookie 策略",@"公共参数与请求适配",@"日志脱敏",@"独立实例取消隔离",@"真实网络上传进度"]; }
@end
