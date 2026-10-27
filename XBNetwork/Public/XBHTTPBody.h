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

/// Multipart（表单中同时包含文本和文件）里的一个文件字段；使用工厂方法创建。
@interface XBHTTPFilePart : NSObject <NSCopying>

/// 服务端约定的字段名，例如 @"avatar"；不是本地文件路径，不能为空。
@property (nonatomic, copy, readonly) NSString *name;
/// 提交给服务端的文件名，例如 @"photo.jpg"；不能为空，不会据此读取本地文件。
@property (nonatomic, copy, readonly) NSString *fileName;
/// 文件内容类型，例如 @"image/jpeg" 或 @"application/octet-stream"，由调用方提供。
@property (nonatomic, copy, readonly) NSString *MIMEType;
/// 复制保存的文件原始字节；需由调用方事先读取到 NSData，不提供文件路径或断点上传接口。
@property (nonatomic, copy, readonly) NSData *data;

/// 保存文件字段，不立即上传；非法字段会在发送时通过 completion 返回构建错误。
/// 多文件上传可将多个字段放入 multipartBodyWithParameters:fileParts: 的 fileParts 数组。
+ (instancetype)partWithName:(NSString *)name
                    fileName:(NSString *)fileName
                    MIMEType:(NSString *)MIMEType
                        data:(NSData *)data;

@end

/**
 HTTP 请求体描述。通过工厂方法明确选择一种编码，再赋给 request.body。

 Form 形如 title=hello，JSON 形如 {"title":"hello"}，Raw 原样发送 NSData，
 Multipart 同时发送普通字段和文件。编码器管理 Content-Type，不需要在 headers 重复设置。
 工厂方法保存数据，实际编码与合法性检查在发送时完成；GET/HEAD 不能使用非 None Body。
 */
@interface XBHTTPBody : NSObject <NSCopying>

/// 决定请求构建器的编码方式。
@property (nonatomic, assign, readonly) XBHTTPBodyType type;
/// 仅 Form 或 Multipart 使用的普通字段；其他类型为 nil。字典只做容器级复制。
@property (nonatomic, copy, readonly, nullable) NSDictionary<NSString *, id> *parameters;
/// 仅 JSON 使用；根对象须为合法字典或数组，合法 JSON 会在创建 Body 时递归快照。
/// 不支持直接以字符串、数字或 NSNull 作为请求 JSON 根对象。
@property (nonatomic, copy, readonly, nullable) id JSONObject;
/// 仅 Raw 使用的原始字节，其他类型为 nil。
@property (nonatomic, copy, readonly, nullable) NSData *rawData;
/// 仅 Raw 使用的非空 Content-Type，例如 @"application/octet-stream"。
@property (nonatomic, copy, readonly, nullable) NSString *contentType;
/// Multipart 文件字段数组，其他类型默认空数组；普通字段与文件字段分别配置。
@property (nonatomic, copy, readonly) NSArray<XBHTTPFilePart *> *fileParts;

/// 显式指定无请求体。
+ (instancetype)none;
/// 创建普通表单描述，发送时按 application/x-www-form-urlencoded 编码。
/// 若需要公共参数合并到此字典，设置 request.commonParameterPlacement = XBCommonParameterPlacementBody。
+ (instancetype)formBodyWithParameters:(NSDictionary<NSString *, id> *)parameters;
/// 创建 JSON 描述；只接受合法字典或数组，发送时编码为 application/json。
/// JSON 数组不能合并公共 Body 参数；数组场景请使用 None 或 Query 合并位置。
+ (instancetype)JSONBodyWithJSONObject:(id)JSONObject;
/// 创建原始字节描述，例如 protobuf 或自定义二进制；data 和非空 contentType 必须同时提供。
/// 不会转换数据，也不能合并公共 Body 参数。
+ (instancetype)rawBodyWithData:(NSData *)data contentType:(NSString *)contentType;
/// 创建 multipart/form-data 描述；parameters 可为 nil，fileParts 中每项须为 XBHTTPFilePart。
/// 编码器生成分隔符 boundary；不要手工覆盖 Content-Type，也不要读取生成后的 HTTPBodyStream 作日志。
+ (instancetype)multipartBodyWithParameters:(nullable NSDictionary<NSString *, id> *)parameters
                                  fileParts:(NSArray<XBHTTPFilePart *> *)fileParts;

@end

NS_ASSUME_NONNULL_END
