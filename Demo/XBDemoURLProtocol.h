#import <Foundation/Foundation.h>
/// Demo 专用的固定本地响应；仅通过 Demo 会话的 protocolClasses 启用，不全局注册、不访问生产接口。
@interface XBDemoURLProtocol : NSURLProtocol
@end
