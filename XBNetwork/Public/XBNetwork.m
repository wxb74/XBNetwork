// 请求入口只负责“配置如何应用”：复制请求 → 合并请求头/公共参数 → 适配器 → 客户端。
// 具体字节编码交给 Builder，网络传输交给 Client，响应解码交给 Parser。
#import "XBNetwork.h"
#import "XBHTTPBody.h"
#import "../Internal/XBNetworkClient.h"
#import <math.h>
@interface XBNetwork ()
@property (nonatomic, strong) XBNetworkClient *client;
@property (nonatomic, copy) XBNetworkConfiguration *configuration;
@end
@implementation XBNetwork
+ (instancetype)sharedNetwork {
    static XBNetwork *network; static dispatch_once_t once;
    dispatch_once(&once, ^{ network = [self new]; });
    return network;
}
- (instancetype)init { return [self initWithConfiguration:[XBNetworkConfiguration new]]; }
- (instancetype)initWithConfiguration:(XBNetworkConfiguration *)configuration {
    if ((self = [super init])) {
        _configuration = [configuration copy] ?: [XBNetworkConfiguration new];
        if (!_configuration.completionQueue) _configuration.completionQueue = dispatch_get_main_queue();
        if (!_configuration.defaultHeaders) _configuration.defaultHeaders = @{};
        _client = [[XBNetworkClient alloc] initWithConfiguration:_configuration];
    }
    return self;
}
- (void)cancelAllRequests { [self.client cancelAllRequests]; }
- (void)invalidateAndCancel { [self.client invalidateAndCancel]; }
- (void)dealloc { [self.client invalidateAndCancel]; }
/// 仅操作本次私有副本，避免公共参数、适配器污染调用方下次复用的描述。
/// 此方法同步执行，Provider/Adapter 不应在这里发起异步准备后再修改副本。
- (XBHTTPRequest *)prepareRequest:(XBHTTPRequest *)request error:(NSError **)error {
    if (![request isKindOfClass:XBHTTPRequest.class]) {
        *error = XBNetworkMakeError(XBNetworkErrorRequestBuildFailed, @"Request is required", nil,nil,nil,nil,nil);
        return nil;
    }
    XBHTTPRequest *copy = [request copy];
    @try {
        NSMutableDictionary *headers = [self.configuration.defaultHeaders mutableCopy];
        // HTTP 头名称不区分大小写：先移除默认头中的同名字段，再写入单请求值。
        for (NSString *key in copy.headers) {
            for (NSString *existing in [headers.allKeys copy]) {
                if ([existing caseInsensitiveCompare:key] == NSOrderedSame) [headers removeObjectForKey:existing];
            }
            headers[key] = copy.headers[key];
        }
        copy.headers = headers;
        // 只有主动选择合并位置才调用 Provider；先放公共字段，再放请求字段实现“请求优先”。
        if (copy.commonParameterPlacement != XBCommonParameterPlacementNone &&
            copy.commonParameterPlacement <= XBCommonParameterPlacementBody) {
            NSDictionary *common = self.configuration.commonParametersProvider ? self.configuration.commonParametersProvider(copy) : @{};
            NSMutableDictionary *merged = [(common ?: @{}) mutableCopy];
            if (copy.commonParameterPlacement == XBCommonParameterPlacementQuery) {
                [merged addEntriesFromDictionary:copy.queryParameters ?: @{}];
                copy.queryParameters = merged;
            } else {
                XBHTTPBody *body = copy.body;
                if (body.type == XBHTTPBodyTypeForm || body.type == XBHTTPBodyTypeMultipart) {
                    [merged addEntriesFromDictionary:body.parameters ?: @{}];
                    copy.body = body.type == XBHTTPBodyTypeForm ? [XBHTTPBody formBodyWithParameters:merged] : [XBHTTPBody multipartBodyWithParameters:merged fileParts:body.fileParts];
                } else if (body.type == XBHTTPBodyTypeJSON && [body.JSONObject isKindOfClass:NSDictionary.class]) {
                    [merged addEntriesFromDictionary:body.JSONObject];
                    copy.body = [XBHTTPBody JSONBodyWithJSONObject:merged];
                } else {
                    // 原始字节、JSON 数组或无 Body 不能直接插入字典字段，必须由调用方改协议配置。
                    *error = XBNetworkMakeError(XBNetworkErrorRequestBuildFailed, @"Common Body parameters require a dictionary JSON, Form or Multipart body",nil,nil,nil,nil,nil);
                    return nil;
                }
            }
            copy.commonParameterPlacement = XBCommonParameterPlacementNone;
        }
        // 适配器最后处理可配置描述，因此签名/鉴权可读取已合并参数；此时还未编码成 URLRequest。
        NSError *adapterError = nil;
        if (self.configuration.requestAdapter && !self.configuration.requestAdapter(copy, &adapterError)) {
            *error = XBNetworkMakeError(XBNetworkErrorRequestBuildFailed, adapterError.localizedDescription ?: @"Request rejected by adapter",nil,nil,nil,nil,adapterError);
            return nil;
        }
        if (!isfinite(copy.timeout) || copy.timeout <= 0) copy.timeout = self.configuration.defaultTimeout;
        return [copy copy];
    } @catch (NSException *exception) {
        *error = XBNetworkMakeError(XBNetworkErrorRequestBuildFailed, @"Invalid request configuration", nil,nil,nil,nil,nil);
        return nil;
    }
}
- (NSURLSessionTask *)GET:(NSString *)URLString
                parameters:(NSDictionary<NSString *,id> *)parameters
                completion:(XBNetworkResultCompletion)completion {
    return [self GET:URLString parameters:parameters headers:nil completion:completion];
}

- (NSURLSessionTask *)GET:(NSString *)URLString
                parameters:(NSDictionary<NSString *,id> *)parameters
                   headers:(NSDictionary<NSString *,NSString *> *)headers
                completion:(XBNetworkResultCompletion)completion {
    XBHTTPRequest *request = [XBHTTPRequest requestWithURLString:URLString method:XBHTTPMethodGET];
    request.queryParameters = (parameters ?: @{});
    request.headers = headers ?: @{};
    request.commonParameterPlacement = XBCommonParameterPlacementQuery;
    return [self sendRequest:request completion:completion];
}

- (NSURLSessionTask *)POSTForm:(NSString *)URLString
                     parameters:(NSDictionary<NSString *,id> *)parameters
                     completion:(XBNetworkResultCompletion)completion {
    return [self POSTForm:URLString parameters:parameters headers:nil completion:completion];
}

- (NSURLSessionTask *)POSTForm:(NSString *)URLString
                     parameters:(NSDictionary<NSString *,id> *)parameters
                        headers:(NSDictionary<NSString *,NSString *> *)headers
                     completion:(XBNetworkResultCompletion)completion {
    XBHTTPRequest *request = [XBHTTPRequest requestWithURLString:URLString method:XBHTTPMethodPOST];
    NSDictionary *bodyParameters = (parameters ?: @{});
    request.body = [XBHTTPBody formBodyWithParameters:bodyParameters];
    request.headers = headers ?: @{};
    request.commonParameterPlacement = XBCommonParameterPlacementBody;
    return [self sendRequest:request completion:completion];
}

- (NSURLSessionTask *)POSTJSON:(NSString *)URLString
                     parameters:(NSDictionary<NSString *,id> *)parameters
                     completion:(XBNetworkResultCompletion)completion {
    return [self POSTJSON:URLString parameters:parameters headers:nil completion:completion];
}

- (NSURLSessionTask *)POSTJSON:(NSString *)URLString
                     parameters:(NSDictionary<NSString *,id> *)parameters
                        headers:(NSDictionary<NSString *,NSString *> *)headers
                     completion:(XBNetworkResultCompletion)completion {
    XBHTTPRequest *request = [XBHTTPRequest requestWithURLString:URLString method:XBHTTPMethodPOST];
    NSDictionary *bodyParameters = (parameters ?: @{});
    request.body = [XBHTTPBody JSONBodyWithJSONObject:bodyParameters];
    request.headers = headers ?: @{};
    request.commonParameterPlacement = XBCommonParameterPlacementBody;
    return [self sendRequest:request completion:completion];
}

- (NSURLSessionTask *)POSTQueryJSON:(NSString *)URLString
                     queryParameters:(NSDictionary<NSString *,id> *)queryParameters
                          JSONObject:(id)JSONObject
                          completion:(XBNetworkResultCompletion)completion {
    XBHTTPRequest *request = [XBHTTPRequest requestWithURLString:URLString method:XBHTTPMethodPOST];
    request.queryParameters = (queryParameters ?: @{});
    request.body = [XBHTTPBody JSONBodyWithJSONObject:JSONObject];
    request.commonParameterPlacement = XBCommonParameterPlacementQuery;
    return [self sendRequest:request completion:completion];
}

- (NSURLSessionTask *)POSTQueryForm:(NSString *)URLString
                    queryParameters:(NSDictionary<NSString *,id> *)queryParameters
                     formParameters:(NSDictionary<NSString *,id> *)formParameters
                         completion:(XBNetworkResultCompletion)completion {
    XBHTTPRequest *request = [XBHTTPRequest requestWithURLString:URLString method:XBHTTPMethodPOST];
    request.queryParameters = queryParameters ?: @{};
    NSDictionary *bodyParameters = (formParameters ?: @{});
    request.body = [XBHTTPBody formBodyWithParameters:bodyParameters];
    request.commonParameterPlacement = XBCommonParameterPlacementBody;
    return [self sendRequest:request completion:completion];
}

- (NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                        completion:(XBNetworkResultCompletion)completion {
    return [self sendRequest:request uploadProgress:nil completion:completion];
}

- (NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                  uploadProgress:(XBNetworkProgress)uploadProgress
                      completion:(XBNetworkResultCompletion)completion {
    // 简化回调与完整回调共用一条发送链路，只在这里取出解析对象，不重复执行网络或解析。
    return [self sendRequest:request
              uploadProgress:uploadProgress
          detailedCompletion:^(XBHTTPResponse *response, NSError *error) {
        if (completion != nil) {
            completion(response.responseObject, error);
        }
    }];
}

- (NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                  uploadProgress:(XBNetworkProgress)uploadProgress
              detailedCompletion:(XBNetworkDetailedCompletion)completion {
    NSError *error = nil;
    XBHTTPRequest *resolved = [self prepareRequest:request error:&error];
    if (!resolved) {
        // 发送前失败也保持异步回调，避免调用方因“有时同步、有时异步”产生状态更新问题。
        if (completion) dispatch_async(self.configuration.completionQueue, ^{ completion(nil, error); });
        return nil;
    }
    return [self.client performRequest:resolved uploadProgress:uploadProgress completion:completion];
}

+ (NSURLSessionTask *)GET:(NSString *)URLString
                        parameters:(NSDictionary<NSString *, id> *)parameters
                        completion:(XBNetworkResultCompletion)completion { return [[self sharedNetwork] GET:URLString parameters:parameters completion:completion]; }
+ (NSURLSessionTask *)GET:(NSString *)URLString
                         parameters:(NSDictionary<NSString *, id> *)parameters
                            headers:(NSDictionary<NSString *, NSString *> *)headers
                         completion:(XBNetworkResultCompletion)completion { return [[self sharedNetwork] GET:URLString parameters:parameters headers:headers completion:completion]; }
+ (NSURLSessionTask *)POSTForm:(NSString *)URLString
                             parameters:(NSDictionary<NSString *, id> *)parameters
                             completion:(XBNetworkResultCompletion)completion { return [[self sharedNetwork] POSTForm:URLString parameters:parameters completion:completion]; }
+ (NSURLSessionTask *)POSTForm:(NSString *)URLString
                             parameters:(NSDictionary<NSString *, id> *)parameters
                                headers:(NSDictionary<NSString *, NSString *> *)headers
                             completion:(XBNetworkResultCompletion)completion { return [[self sharedNetwork] POSTForm:URLString parameters:parameters headers:headers completion:completion]; }
+ (NSURLSessionTask *)POSTJSON:(NSString *)URLString
                             parameters:(NSDictionary<NSString *, id> *)parameters
                             completion:(XBNetworkResultCompletion)completion { return [[self sharedNetwork] POSTJSON:URLString parameters:parameters completion:completion]; }
+ (NSURLSessionTask *)POSTJSON:(NSString *)URLString
                              parameters:(NSDictionary<NSString *, id> *)parameters
                                 headers:(NSDictionary<NSString *, NSString *> *)headers
                              completion:(XBNetworkResultCompletion)completion { return [[self sharedNetwork] POSTJSON:URLString parameters:parameters headers:headers completion:completion]; }
+ (NSURLSessionTask *)POSTQueryJSON:(NSString *)URLString
                             queryParameters:(NSDictionary<NSString *, id> *)queryParameters
                                  JSONObject:(id)JSONObject
                                  completion:(XBNetworkResultCompletion)completion { return [[self sharedNetwork] POSTQueryJSON:URLString queryParameters:queryParameters JSONObject:JSONObject completion:completion]; }
+ (NSURLSessionTask *)POSTQueryForm:(NSString *)URLString
                              queryParameters:(NSDictionary<NSString *, id> *)queryParameters
                               formParameters:(NSDictionary<NSString *, id> *)formParameters
                                   completion:(XBNetworkResultCompletion)completion { return [[self sharedNetwork] POSTQueryForm:URLString queryParameters:queryParameters formParameters:formParameters completion:completion]; }
+ (NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                                completion:(XBNetworkResultCompletion)completion { return [[self sharedNetwork] sendRequest:request completion:completion]; }
+ (NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                            uploadProgress:(XBNetworkProgress)uploadProgress
                                completion:(XBNetworkResultCompletion)completion { return [[self sharedNetwork] sendRequest:request uploadProgress:uploadProgress completion:completion]; }
+ (NSURLSessionTask *)sendRequest:(XBHTTPRequest *)request
                            uploadProgress:(XBNetworkProgress)uploadProgress
                        detailedCompletion:(XBNetworkDetailedCompletion)completion { return [[self sharedNetwork] sendRequest:request uploadProgress:uploadProgress detailedCompletion:completion]; }
+ (void)cancelAllRequests { [[self sharedNetwork] cancelAllRequests]; }
@end
