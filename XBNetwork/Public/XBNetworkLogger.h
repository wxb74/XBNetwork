#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// Optional observer. Events contain metadata only: body omitted; query, credentials and header values redacted.
/// May be called on different threads. Implementations must be thread safe. Exceptions are isolated.
@protocol XBNetworkLogger <NSObject>
- (void)networkDidRecordEvent:(NSDictionary<NSString *, id> *)event;
@end
NS_ASSUME_NONNULL_END
