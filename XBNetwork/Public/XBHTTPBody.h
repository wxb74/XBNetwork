//
//  XBHTTPBody.h
//  XBNetwork
//
//  明确描述 HTTP Body 的编码方式，避免业务参数在 Form、JSON 和 URL 之间隐式切换。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, XBHTTPBodyType) {
    /// 请求不携带 Body。
    XBHTTPBodyTypeNone = 0,
    /// application/x-www-form-urlencoded。
    XBHTTPBodyTypeForm,
    /// application/json。
    XBHTTPBodyTypeJSON,
    /// 调用方提供已经编码完成的 NSData。
    XBHTTPBodyTypeRawData,
    /// multipart/form-data，适用于图片和文件上传。
    XBHTTPBodyTypeMultipart
};

/// Multipart 中的一个文件字段。字段名、文件名和 MIME Type 均由接口协议明确指定。
@interface XBHTTPFilePart : NSObject <NSCopying>

/// Multipart 字段名。
@property (nonatomic, copy, readonly) NSString *name;
/// 提交给服务端的文件名。
@property (nonatomic, copy, readonly) NSString *fileName;
/// 此文件字段的 MIME 类型。
@property (nonatomic, copy, readonly) NSString *MIMEType;
/// 文件原始字节。
@property (nonatomic, copy, readonly) NSData *data;

/// 创建一个完整的文件字段，构建请求时会校验这些值。
+ (instancetype)partWithName:(NSString *)name
                    fileName:(NSString *)fileName
                    MIMEType:(NSString *)MIMEType
                        data:(NSData *)data;

@end

/// HTTP Body 值对象。业务层通过工厂方法选择编码类型，不直接设置 Content-Type。
@interface XBHTTPBody : NSObject <NSCopying>

/// 决定请求构建器的编码方式。
@property (nonatomic, assign, readonly) XBHTTPBodyType type;
/// Form 或 Multipart 的普通字段。
@property (nonatomic, copy, readonly, nullable) NSDictionary<NSString *, id> *parameters;
/// JSON Body 的根对象，必须是合法的 NSDictionary 或 NSArray。
@property (nonatomic, copy, readonly, nullable) id JSONObject;
/// Raw Body 的原始数据。
@property (nonatomic, copy, readonly, nullable) NSData *rawData;
/// Raw Body 的 Content-Type。
@property (nonatomic, copy, readonly, nullable) NSString *contentType;
/// Multipart 文件字段。
@property (nonatomic, copy, readonly) NSArray<XBHTTPFilePart *> *fileParts;

/// 显式指定无请求体。
+ (instancetype)none;
/// 将字典编码为普通表单请求体。
+ (instancetype)formBodyWithParameters:(NSDictionary<NSString *, id> *)parameters;
/// 延迟将合法 JSON 根对象编码为请求体。
+ (instancetype)JSONBodyWithJSONObject:(id)JSONObject;
/// 发送调用方已编码的字节和内容类型。
+ (instancetype)rawBodyWithData:(NSData *)data contentType:(NSString *)contentType;
/// 同时提交普通表单字段与文件字段。
+ (instancetype)multipartBodyWithParameters:(nullable NSDictionary<NSString *, id> *)parameters
                                  fileParts:(NSArray<XBHTTPFilePart *> *)fileParts;

@end

NS_ASSUME_NONNULL_END
