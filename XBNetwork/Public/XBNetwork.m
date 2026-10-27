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
- (XBHTTPRequest *)prepareRequest:(XBHTTPRequest *)request error:(NSError **)error {
    if (![request isKindOfClass:XBHTTPRequest.class]) {
        *error = XBNetworkMakeError(XBNetworkErrorRequestBuildFailed, @"Request is required", nil,nil,nil,nil,nil);
        return nil;
    }
    XBHTTPRequest *copy = [request copy];
    @try {
        NSMutableDictionary *headers = [self.configuration.defaultHeaders mutableCopy];
        // Header names are case insensitive; explicit per-request values win.
        for (NSString *key in copy.headers) {
            for (NSString *existing in [headers.allKeys copy]) {
                if ([existing caseInsensitiveCompare:key] == NSOrderedSame) [headers removeObjectForKey:existing];
            }
            headers[key] = copy.headers[key];
        }
        copy.headers = headers;
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
                    *error = XBNetworkMakeError(XBNetworkErrorRequestBuildFailed, @"Common Body parameters require a dictionary JSON, Form or Multipart body",nil,nil,nil,nil,nil);
                    return nil;
                }
            }
            copy.commonParameterPlacement = XBCommonParameterPlacementNone;
        }
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
