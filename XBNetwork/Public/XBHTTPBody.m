//
//  XBHTTPBody.m
//  XBNetwork
//

#import "XBHTTPBody.h"

@interface XBHTTPFilePart ()

/// Multipart 字段名。
@property (nonatomic, copy, readwrite) NSString *name;
/// 服务端接收的文件名。
@property (nonatomic, copy, readwrite) NSString *fileName;
/// 文件内容类型。
@property (nonatomic, copy, readwrite) NSString *MIMEType;
/// 实际上传的二进制数据。
@property (nonatomic, copy, readwrite) NSData *data;

@end

@implementation XBHTTPFilePart

/// 将单个 multipart 文件字段封装为不可变快照。
+ (instancetype)partWithName:(NSString *)name
                    fileName:(NSString *)fileName
                    MIMEType:(NSString *)MIMEType
                        data:(NSData *)data {
    XBHTTPFilePart *part = [[self alloc] init];
    part.name = name;
    part.fileName = fileName;
    part.MIMEType = MIMEType;
    part.data = data;
    return part;
}

/// 拷贝时保留字段名、元数据和数据，避免发送期间被外部改动。
- (id)copyWithZone:(NSZone *)zone {
    return [XBHTTPFilePart partWithName:self.name
                               fileName:self.fileName
                               MIMEType:self.MIMEType
                                   data:self.data];
}

@end

@interface XBHTTPBody ()

/// 决定 Builder 采用哪种编码方式。
@property (nonatomic, assign, readwrite) XBHTTPBodyType type;
/// Form 或 Multipart 的普通表单字段。
@property (nonatomic, copy, readwrite, nullable) NSDictionary<NSString *, id> *parameters;
/// JSON 编码的根对象，合法性由 Builder 校验。
@property (nonatomic, copy, readwrite, nullable) id JSONObject;
/// Raw Body 的原始字节。
@property (nonatomic, copy, readwrite, nullable) NSData *rawData;
/// Raw Body 对应的 Content-Type。
@property (nonatomic, copy, readwrite, nullable) NSString *contentType;
/// Multipart 中的文件字段列表。
@property (nonatomic, copy, readwrite) NSArray<XBHTTPFilePart *> *fileParts;

/// 所有工厂方法最终都通过同一个初始化入口生成不可变 Body，防止不同编码类型残留无关字段。
- (instancetype)initWithType:(XBHTTPBodyType)type
                  parameters:(nullable NSDictionary<NSString *, id> *)parameters
                  JSONObject:(nullable id)JSONObject
                     rawData:(nullable NSData *)rawData
                 contentType:(nullable NSString *)contentType
                   fileParts:(NSArray<XBHTTPFilePart *> *)fileParts;

@end

@implementation XBHTTPBody

/// 不发送请求体，适用于 GET 等请求。
+ (instancetype)none {
    return [[self alloc] initWithType:XBHTTPBodyTypeNone
                          parameters:nil
                          JSONObject:nil
                             rawData:nil
                         contentType:nil
                           fileParts:@[]];
}

/// 生成 application/x-www-form-urlencoded 请求体。
+ (instancetype)formBodyWithParameters:(NSDictionary<NSString *,id> *)parameters {
    return [[self alloc] initWithType:XBHTTPBodyTypeForm
                          parameters:parameters
                          JSONObject:nil
                             rawData:nil
                         contentType:nil
                           fileParts:@[]];
}

/// 保存 JSON 根对象，具体序列化推迟到请求构建阶段。
+ (instancetype)JSONBodyWithJSONObject:(id)JSONObject {
    return [[self alloc] initWithType:XBHTTPBodyTypeJSON
                          parameters:nil
                          JSONObject:JSONObject
                             rawData:nil
                         contentType:nil
                           fileParts:@[]];
}

/// 原样发送字节，并使用调用方指定的内容类型。
+ (instancetype)rawBodyWithData:(NSData *)data contentType:(NSString *)contentType {
    return [[self alloc] initWithType:XBHTTPBodyTypeRawData
                          parameters:nil
                          JSONObject:nil
                             rawData:data
                         contentType:contentType
                           fileParts:@[]];
}

/// 同时编码普通字段和文件字段的 multipart 请求体。
+ (instancetype)multipartBodyWithParameters:(NSDictionary<NSString *,id> *)parameters
                                  fileParts:(NSArray<XBHTTPFilePart *> *)fileParts {
    return [[self alloc] initWithType:XBHTTPBodyTypeMultipart
                          parameters:parameters
                          JSONObject:nil
                             rawData:nil
                         contentType:nil
                           fileParts:fileParts];
}

/// 统一复制各类型字段，保证发送时 Body 的内容稳定。
- (instancetype)initWithType:(XBHTTPBodyType)type
                  parameters:(NSDictionary<NSString *, id> *)parameters
                  JSONObject:(id)JSONObject
                     rawData:(NSData *)rawData
                 contentType:(NSString *)contentType
                   fileParts:(NSArray<XBHTTPFilePart *> *)fileParts {
    self = [super init];
    if (self) {
        _type = type;
        _parameters = [parameters copy];
        // JSON 根对象是 id，先避免对不支持 NSCopying 的误传对象发送 copy 而崩溃；
        // 合法性由 Builder 在发送前统一校验并通过 completion 返回错误。
        if ([JSONObject isKindOfClass:NSDictionary.class] || [JSONObject isKindOfClass:NSArray.class]) {
            if ([NSJSONSerialization isValidJSONObject:JSONObject]) {
                NSData *snapshot = [NSJSONSerialization dataWithJSONObject:JSONObject options:0 error:NULL];
                _JSONObject = [NSJSONSerialization JSONObjectWithData:snapshot options:0 error:NULL];
            } else {
                _JSONObject = [JSONObject copy];
            }
        } else {
            _JSONObject = [JSONObject conformsToProtocol:@protocol(NSCopying)] ? [JSONObject copy] : JSONObject;
        }
        _rawData = [rawData copy];
        _contentType = [contentType copy];
        _fileParts = [fileParts copy] ?: @[];
    }
    return self;
}

/// 请求快照复制时保留 Body 编码类型及关联字段。
- (id)copyWithZone:(NSZone *)zone {
    return [[XBHTTPBody alloc] initWithType:self.type
                                parameters:self.parameters
                                JSONObject:self.JSONObject
                                   rawData:self.rawData
                               contentType:self.contentType
                                 fileParts:self.fileParts];
}

@end
