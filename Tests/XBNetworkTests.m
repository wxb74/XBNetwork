#import <XCTest/XCTest.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <unistd.h>
#import <XBNetwork/XBNetworkUmbrella.h>
#import "../XBNetwork/Internal/XBHTTPRequestBuilder.h"
#import "../Demo/XBDemoURLProtocol.h"
#import "../Demo/XBDemoCatalog.h"

@interface XBTestLogger : NSObject <XBNetworkLogger>
@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic) BOOL throws;
@end
@implementation XBTestLogger
- (instancetype)init { if ((self=[super init])) _events=[NSMutableArray array]; return self; }
- (void)networkDidRecordEvent:(NSDictionary *)event { @synchronized(self) { [self.events addObject:event]; } if(self.throws) [NSException raise:@"logger" format:@"fixture"]; }
@end

@interface XBNetworkTests : XCTestCase
@property (nonatomic, strong) XBNetwork *network;
@end
@implementation XBNetworkTests
- (XBNetworkConfiguration *)configuration {
    XBNetworkConfiguration *config=[XBNetworkConfiguration new];
    config.sessionConfiguration=[NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.sessionConfiguration.protocolClasses=@[XBDemoURLProtocol.class];
    return config;
}
- (void)setUp { [super setUp]; self.network=[[XBNetwork alloc] initWithConfiguration:[self configuration]]; }
- (void)tearDown { [self.network invalidateAndCancel]; self.network=nil; [super tearDown]; }
- (XBHTTPRequest *)request:(NSString *)path { return [XBHTTPRequest requestWithURLString:[@"https://demo.xbnetwork.invalid" stringByAppendingString:path] method:XBHTTPMethodGET]; }
- (XBHTTPResponse *)response:(XBHTTPRequest *)request error:(NSError **)outError {
    XCTestExpectation *e=[self expectationWithDescription:@"completion"]; __block XBHTTPResponse *result; __block NSError *failure;
    [self.network sendRequest:request uploadProgress:nil detailedCompletion:^(XBHTTPResponse *response,NSError *error) { result=response; failure=error; [e fulfill]; }];
    [self waitForExpectations:@[e] timeout:3]; if(outError) *outError=failure; return result;
}
- (void)testGETEncodesUnicodeArraysAndExistingQuery {
    XBHTTPRequest *r=[self request:@"/echo?fixed=1"]; r.queryParameters=@{@"q":@"中文 & +",@"items":@[@1,@2]};
    NSError *error; NSDictionary *echo=[self response:r error:&error].responseObject;
    XCTAssertNil(error); NSURLComponents *c=[NSURLComponents componentsWithString:echo[@"URL"]];
    XCTAssertTrue([c.queryItems containsObject:[NSURLQueryItem queryItemWithName:@"q" value:@"中文 & +"]]);
    XCTAssertTrue([c.queryItems containsObject:[NSURLQueryItem queryItemWithName:@"fixed" value:@"1"]]); XCTAssertEqual(c.queryItems.count,4u);
}
- (void)testFormKeepsQueryAndBodySeparate {
    XBHTTPRequest *r=[self request:@"/echo"]; r.method=XBHTTPMethodPOST; r.queryParameters=@{@"route":@"x"}; r.body=[XBHTTPBody formBodyWithParameters:@{@"message":@"a+b & c"}];
    NSDictionary *echo=[self response:r error:NULL].responseObject;
    XCTAssertTrue([echo[@"URL"] containsString:@"route=x"]); XCTAssertFalse([echo[@"URL"] containsString:@"message"]);
    XCTAssertTrue([echo[@"body"] containsString:@"a%2Bb%20%26%20c"]);
}
- (void)testJSONPreservesNestedValues {
    XBHTTPRequest *r=[self request:@"/echo"]; r.method=XBHTTPMethodPOST; NSDictionary *payload=@{@"list":@[@{@"id":@3}],@"enabled":@YES}; r.body=[XBHTTPBody JSONBodyWithJSONObject:payload];
    NSDictionary *echo=[self response:r error:NULL].responseObject; NSDictionary *json=[NSJSONSerialization JSONObjectWithData:[echo[@"body"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL]; XCTAssertEqualObjects(json,payload);
}
- (void)testRawBodyAndContentType {
    XBHTTPRequest *r=[self request:@"/echo"]; r.method=XBHTTPMethodPUT; r.body=[XBHTTPBody rawBodyWithData:[@"raw+data" dataUsingEncoding:NSUTF8StringEncoding] contentType:@"text/plain"]; NSDictionary *echo=[self response:r error:NULL].responseObject; XCTAssertEqualObjects(echo[@"body"],@"raw+data"); XCTAssertEqualObjects(echo[@"headers"][@"Content-Type"],@"text/plain");
}
- (void)testMultipartContainsFieldsAndFileBytes {
    XBHTTPRequest *r=[self request:@"/echo"]; r.method=XBHTTPMethodPOST; r.body=[XBHTTPBody multipartBodyWithParameters:@{@"caption":@"sample"} fileParts:@[[XBHTTPFilePart partWithName:@"file" fileName:@"a.txt" MIMEType:@"text/plain" data:[@"file-bytes" dataUsingEncoding:NSUTF8StringEncoding]]]];
    NSDictionary *echo=[self response:r error:NULL].responseObject; XCTAssertTrue([echo[@"body"] containsString:@"file-bytes"]); XCTAssertTrue([echo[@"body"] containsString:@"sample"]); XCTAssertTrue([echo[@"headers"][@"Content-Type"] hasPrefix:@"multipart/form-data; boundary="]);
}
- (void)testGeneratedContentTypeCannotBeOverridden {
    XBHTTPRequest *r=[self request:@"/echo"]; r.method=XBHTTPMethodPOST; r.body=[XBHTTPBody JSONBodyWithJSONObject:@{}]; r.headers=@{@"content-type":@"text/plain"}; NSDictionary *echo=[self response:r error:NULL].responseObject; XCTAssertEqualObjects(echo[@"headers"][@"Content-Type"],@"application/json");
}
- (void)testAllHTTPMethods {
    for(NSUInteger m=0;m<=XBHTTPMethodHEAD;m++){ XBHTTPRequest *r=[self request:@"/echo"]; r.method=m; r.allowsEmptyResponse=YES; NSError *error; XBHTTPResponse *response=[self response:r error:&error]; XCTAssertNil(error); XCTAssertEqualObjects(response.URLRequest.HTTPMethod,XBHTTPMethodString(m)); }
}
- (void)testGETWithBodyFailsAsynchronously {
    XBHTTPRequest *r=[self request:@"/echo"]; r.body=[XBHTTPBody JSONBodyWithJSONObject:@{}]; __block BOOL returned=NO; XCTestExpectation *e=[self expectationWithDescription:@"async failure"];
    NSURLSessionTask *task=[self.network sendRequest:r completion:^(id object,NSError *error){ XCTAssertTrue(returned); XCTAssertNil(object); XCTAssertEqual(error.code,XBNetworkErrorRequestBuildFailed); [e fulfill]; }]; returned=YES; XCTAssertNil(task); [self waitForExpectations:@[e] timeout:1];
}
- (void)testInvalidAndUnsupportedURLsFail {
    for(NSString *URL in @[@"",@"not a url",@"file://localhost/tmp/test",@"ftp://example.com/file"]){ XBHTTPRequest *r=[XBHTTPRequest requestWithURLString:URL method:XBHTTPMethodGET]; NSError *error; XCTAssertNil([self response:r error:&error]); XCTAssertEqual(error.code,XBNetworkErrorRequestBuildFailed); }
}
- (void)testNilRequestFailsWithoutCrash { NSError *error; XCTAssertNil([self response:nil error:&error]); XCTAssertEqual(error.code,XBNetworkErrorRequestBuildFailed); }
- (void)testInvalidJSONObjectFails { XBHTTPRequest *r=[self request:@"/echo"]; r.method=XBHTTPMethodPOST; r.body=[XBHTTPBody JSONBodyWithJSONObject:@"invalid-root"]; NSError *error; XCTAssertNil([self response:r error:&error]); XCTAssertEqual(error.code,XBNetworkErrorRequestBuildFailed); }
- (void)testNon2xxPreservesResponseMetadataAndBody {
    NSError *error; XCTAssertNil([self response:[self request:@"/status/401"] error:&error]); XCTAssertEqual(error.code,XBNetworkErrorUnacceptableStatusCode); XCTAssertEqual([error.userInfo[XBNetworkErrorResponseKey] statusCode],401); XCTAssertNotNil(error.userInfo[XBNetworkErrorResponseDataKey]); XCTAssertNotNil(error.userInfo[XBNetworkErrorResponseObjectKey]);
}
- (void)testCustomAcceptedStatusCode { XBHTTPRequest *r=[self request:@"/status/404"]; r.acceptableStatusCodes=[NSIndexSet indexSetWithIndex:404]; NSError *error; XCTAssertNotNil([self response:r error:&error]); XCTAssertNil(error); }
- (void)testEmptyResponseRequiresOptIn { XBHTTPRequest *r=[self request:@"/empty"]; NSError *error; XCTAssertNil([self response:r error:&error]); XCTAssertEqual(error.code,XBNetworkErrorEmptyResponse); r.allowsEmptyResponse=YES; XBHTTPResponse *response=[self response:r error:&error]; XCTAssertNil(error); XCTAssertEqual(response.HTTPResponse.statusCode,204); XCTAssertEqual(response.data.length,0u); }
- (void)testInvalidJSONResponseFails { NSError *error; XCTAssertNil([self response:[self request:@"/invalid"] error:&error]); XCTAssertEqual(error.code,XBNetworkErrorResponseDecodingFailed); XCTAssertNotNil(error.userInfo[NSUnderlyingErrorKey]); }
- (void)testTextResponse { XBHTTPRequest *r=[self request:@"/text"]; r.responseType=XBHTTPResponseTypeString; XCTAssertEqualObjects([self response:r error:NULL].responseObject,@"Hello XBNetwork"); }
- (void)testBinaryResponse { XBHTTPRequest *r=[self request:@"/binary"]; r.responseType=XBHTTPResponseTypeData; NSData *data=[self response:r error:NULL].responseObject; XCTAssertEqual(data.length,3u); XCTAssertEqual(((const unsigned char *)data.bytes)[2],255); }
- (void)testInvalidUTF8Fails { XBHTTPRequest *r=[self request:@"/binary"]; r.responseType=XBHTTPResponseTypeString; NSError *error; XCTAssertNil([self response:r error:&error]); XCTAssertEqual(error.code,XBNetworkErrorResponseDecodingFailed); }
- (void)testCookieDisabledStripsExplicitCookie { XBHTTPRequest *r=[self request:@"/echo"]; r.headers=@{@"cOoKiE":@"fixture=1"}; NSDictionary *echo=[self response:r error:NULL].responseObject; for(NSString *key in echo[@"headers"]) XCTAssertNotEqual([key caseInsensitiveCompare:@"Cookie"],NSOrderedSame); XCTAssertFalse([echo[@"cookieHandling"] boolValue]); }
- (void)testSystemCookiePolicyAllowsExplicitCookie { XBHTTPRequest *r=[self request:@"/echo"]; r.cookiePolicy=XBHTTPCookiePolicySystem; r.headers=@{@"Cookie":@"fixture=1"}; NSDictionary *echo=[self response:r error:NULL].responseObject; XCTAssertEqualObjects(echo[@"headers"][@"Cookie"],@"fixture=1"); XCTAssertTrue([echo[@"cookieHandling"] boolValue]); }
- (void)testTransportErrorClassification { NSError *error; [self response:[self request:@"/offline"] error:&error]; XCTAssertTrue(XBNetworkErrorIsNotConnected(error)); XCTAssertEqual(error.code,XBNetworkErrorNotConnected); }
- (void)testCancellationDeliversOnce {
    XCTestExpectation *e=[self expectationWithDescription:@"cancel"]; e.assertForOverFulfill=YES;
    NSURLSessionTask *task=[self.network sendRequest:[self request:@"/slow"] completion:^(id object,NSError *error){ XCTAssertTrue(XBNetworkErrorIsCancellation(error)); [e fulfill]; }]; [task cancel]; [self waitForExpectations:@[e] timeout:1];
}
- (void)testTotalTimeoutDeliversOnceDespiteLaterTransportCompletion {
    XCTestExpectation *e=[self expectationWithDescription:@"deadline"]; e.assertForOverFulfill=YES; __block NSUInteger count=0;
    XBHTTPRequest *r=[self request:@"/slow"]; r.totalTimeout=.03;
    [self.network sendRequest:r completion:^(id object,NSError *error){ count++; XCTAssertTrue(XBNetworkErrorIsTimeout(error)); [e fulfill]; }];
    [self waitForExpectations:@[e] timeout:1]; XCTestExpectation *settled=[self expectationWithDescription:@"settle"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(), ^{ XCTAssertEqual(count,1u); [settled fulfill]; }); [self waitForExpectations:@[settled] timeout:1];
}
- (void)testCancelAllDoesNotAffectOtherInstance {
    XBNetwork *other=[[XBNetwork alloc] initWithConfiguration:[self configuration]];
    XCTestExpectation *cancel=[self expectationWithDescription:@"cancel own"],*success=[self expectationWithDescription:@"other succeeds"];
    [self.network sendRequest:[self request:@"/slow"] completion:^(id object,NSError *error){ XCTAssertTrue(XBNetworkErrorIsCancellation(error)); [cancel fulfill]; }];
    [other sendRequest:[self request:@"/slow"] completion:^(id object,NSError *error){ XCTAssertNil(error); XCTAssertNotNil(object); [success fulfill]; }]; [self.network cancelAllRequests]; [self waitForExpectations:@[cancel,success] timeout:2]; [other invalidateAndCancel];
}
- (void)testClosedInstanceReturnsCancellation { [self.network invalidateAndCancel]; NSError *error; XCTAssertNil([self response:[self request:@"/echo"] error:&error]); XCTAssertTrue(XBNetworkErrorIsCancellation(error)); }
- (void)testCallbacksDefaultToMainThread { XCTestExpectation *e=[self expectationWithDescription:@"queue"]; [self.network sendRequest:[self request:@"/echo"] completion:^(id object,NSError *error){ XCTAssertTrue(NSThread.isMainThread); [e fulfill]; }]; [self waitForExpectations:@[e] timeout:1]; }
- (void)testCustomCallbackQueue {
    XBNetworkConfiguration *c=[self configuration]; dispatch_queue_t queue=dispatch_queue_create("test.callback",DISPATCH_QUEUE_SERIAL); static int key; dispatch_queue_set_specific(queue,&key,&key,NULL); c.completionQueue=queue; self.network=[[XBNetwork alloc] initWithConfiguration:c]; XCTestExpectation *e=[self expectationWithDescription:@"queue"]; [self.network sendRequest:[self request:@"/echo"] completion:^(id object,NSError *error){ XCTAssertNotEqual(dispatch_get_specific(&key),NULL); [e fulfill]; }]; [self waitForExpectations:@[e] timeout:1];
}
- (void)testDefaultHeadersSnapshotAndCaseInsensitiveOverride {
    XBNetworkConfiguration *c=[self configuration]; c.defaultHeaders=@{@"Authorization":@"old",@"X-Default":@"yes"}; self.network=[[XBNetwork alloc] initWithConfiguration:c]; c.defaultHeaders=@{@"X-Default":@"changed"}; XBHTTPRequest *r=[self request:@"/echo"]; r.headers=@{@"authorization":@"new"}; NSDictionary *echo=[self response:r error:NULL].responseObject; XCTAssertEqualObjects(echo[@"headers"][@"X-Default"],@"yes"); __block NSUInteger auth=0; [echo[@"headers"] enumerateKeysAndObjectsUsingBlock:^(NSString *key,id value,BOOL *stop){ if([key caseInsensitiveCompare:@"Authorization"]==NSOrderedSame){ auth++; XCTAssertEqualObjects(value,@"new"); } }]; XCTAssertEqual(auth,1u);
}
- (void)testCommonQueryParametersAreDynamicAndExplicitFieldsWin {
    XBNetworkConfiguration *c=[self configuration]; __block NSString *account=@"one"; c.commonParametersProvider=^NSDictionary *(XBHTTPRequest *r){ return @{@"account":account,@"page":@1}; }; self.network=[[XBNetwork alloc] initWithConfiguration:c];
    for(NSString *value in @[@"one",@"two"]){ account=value; XBHTTPRequest *r=[self request:@"/echo"]; r.commonParameterPlacement=XBCommonParameterPlacementQuery; r.queryParameters=@{@"page":@2}; NSDictionary *echo=[self response:r error:NULL].responseObject; XCTAssertTrue([echo[@"URL"] containsString:[@"account=" stringByAppendingString:value]]); XCTAssertTrue([echo[@"URL"] containsString:@"page=2"]); }
}
- (void)testCommonParametersAreNotAddedWithoutOptIn {
    XBNetworkConfiguration *c=[self configuration]; c.commonParametersProvider=^NSDictionary *(XBHTTPRequest *r){ return @{@"secret":@"value"}; }; self.network=[[XBNetwork alloc] initWithConfiguration:c]; NSDictionary *echo=[self response:[self request:@"/echo"] error:NULL].responseObject; XCTAssertFalse([echo[@"URL"] containsString:@"secret"]);
}
- (void)testCommonBodyMergeAndUnsupportedBodyFailure {
    XBNetworkConfiguration *c=[self configuration]; c.commonParametersProvider=^NSDictionary *(XBHTTPRequest *r){ return @{@"common":@YES,@"id":@1}; }; self.network=[[XBNetwork alloc] initWithConfiguration:c]; XBHTTPRequest *r=[self request:@"/echo"]; r.method=XBHTTPMethodPOST; r.commonParameterPlacement=XBCommonParameterPlacementBody; r.body=[XBHTTPBody JSONBodyWithJSONObject:@{@"id":@2}]; NSDictionary *echo=[self response:r error:NULL].responseObject; NSDictionary *payload=[NSJSONSerialization JSONObjectWithData:[echo[@"body"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL]; XCTAssertEqualObjects(payload,(@{@"common":@YES,@"id":@2})); r.body=[XBHTTPBody JSONBodyWithJSONObject:@[@1]]; NSError *error; XCTAssertNil([self response:r error:&error]); XCTAssertEqual(error.code,XBNetworkErrorRequestBuildFailed);
}
- (void)testAdapterCanRejectAndThrowWithoutSkippingCompletion {
    for(NSNumber *throws in @[@NO,@YES]){ XBNetworkConfiguration *c=[self configuration]; c.requestAdapter=^BOOL(XBHTTPRequest *r,NSError **error){ if(throws.boolValue) [NSException raise:@"adapter" format:@"fixture"]; *error=[NSError errorWithDomain:@"test" code:1 userInfo:@{NSLocalizedDescriptionKey:@"rejected"}]; return NO; }; self.network=[[XBNetwork alloc] initWithConfiguration:c]; NSError *error; XCTAssertNil([self response:[self request:@"/echo"] error:&error]); XCTAssertEqual(error.code,XBNetworkErrorRequestBuildFailed); }
}
- (void)testJSONBodyDeepSnapshot {
    NSMutableDictionary *child=[@{@"value":@"before"} mutableCopy]; XBHTTPRequest *r=[self request:@"/echo"]; r.method=XBHTTPMethodPOST; r.body=[XBHTTPBody JSONBodyWithJSONObject:@{@"child":child}]; child[@"value"]=@"after"; NSDictionary *echo=[self response:r error:NULL].responseObject; XCTAssertTrue([echo[@"body"] containsString:@"before"]); XCTAssertFalse([echo[@"body"] containsString:@"after"]);
}
- (void)testRequestMutationAfterSendDoesNotChangeResponseParsing {
    XCTestExpectation *e=[self expectationWithDescription:@"snapshot"]; XBHTTPRequest *r=[self request:@"/text"]; r.responseType=XBHTTPResponseTypeString; [self.network sendRequest:r completion:^(id object,NSError *error){ XCTAssertNil(error); XCTAssertEqualObjects(object,@"Hello XBNetwork"); [e fulfill]; }]; r.responseType=XBHTTPResponseTypeJSON; [self waitForExpectations:@[e] timeout:1];
}
- (void)testLoggerRedactsSecretsAndCannotBreakRequest {
    for(NSNumber *throws in @[@NO,@YES]){ XBTestLogger *logger=[XBTestLogger new]; logger.throws=throws.boolValue; XBNetworkConfiguration *c=[self configuration]; c.logger=logger; self.network=[[XBNetwork alloc] initWithConfiguration:c]; XBHTTPRequest *r=[self request:@"/echo?token=sensitive-value"]; r.headers=@{@"Authorization":@"Bearer sensitive-value"}; NSError *error; XCTAssertNotNil([self response:r error:&error]); XCTAssertNil(error); XCTAssertEqual(logger.events.count,2u); NSString *events=logger.events.description; XCTAssertFalse([events containsString:@"sensitive-value"]); XCTAssertTrue([events containsString:@"REDACTED"]); }
}
- (void)testErrorHelpersRecognizeUnderlyingErrorsAndUseStandardDescription {
    NSError *under=[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]; NSError *wrapped=[NSError errorWithDomain:@"wrapper" code:1 userInfo:@{NSUnderlyingErrorKey:under}]; XCTAssertTrue(XBNetworkErrorIsTimeout(wrapped)); NSError *e=[NSError errorWithDomain:@"technical.domain" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Readable message"}]; XCTAssertEqualObjects(XBNetworkErrorDisplayMessage(e,@"fallback"),@"Readable message");
}
- (void)testConfiguredDefaultTimeoutAndListBudget {
    XBNetworkConfiguration *c=[self configuration]; c.defaultTimeout=7; self.network=[[XBNetwork alloc] initWithConfiguration:c]; XCTAssertEqualWithAccuracy([self response:[self request:@"/echo"] error:NULL].URLRequest.timeoutInterval,7,.001); XBHTTPRequest *r=[XBHTTPRequest listRequestWithURLString:@"https://demo.xbnetwork.invalid/echo" method:XBHTTPMethodPOST]; XCTAssertEqual(r.timeout,8); XCTAssertEqual(r.totalTimeout,10);
}
- (void)testDemoCatalogHasEveryExample { XCTAssertEqual(XBDemoCatalog.titles.count,18u); XCTAssertTrue([XBDemoCatalog.titles containsObject:@"真实网络上传进度"]); }

- (void)testRealLoopbackUploadDeliversProgressAndStopsAfterCompletion {
    int listener=socket(AF_INET,SOCK_STREAM,0); XCTAssertGreaterThanOrEqual(listener,0);
    struct sockaddr_in address={0}; address.sin_family=AF_INET; address.sin_addr.s_addr=htonl(INADDR_LOOPBACK); address.sin_port=0;
    XCTAssertEqual(bind(listener,(struct sockaddr *)&address,sizeof(address)),0); XCTAssertEqual(listen(listener,1),0);
    socklen_t length=sizeof(address); getsockname(listener,(struct sockaddr *)&address,&length); unsigned port=ntohs(address.sin_port);
    XCTestExpectation *served=[self expectationWithDescription:@"server completed"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
        fd_set fds; FD_ZERO(&fds); FD_SET(listener,&fds); struct timeval wait={5,0};
        if(select(listener+1,&fds,NULL,NULL,&wait)<=0){close(listener); [served fulfill]; return;}
        int fd=accept(listener,NULL,NULL); struct timeval timeout={3,0}; setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));
        NSMutableData *headers=[NSMutableData data]; unsigned char c; const unsigned char end[]={13,10,13,10};
        while(headers.length<65536 && recv(fd,&c,1,0)==1){[headers appendBytes:&c length:1]; if(headers.length>=4 && memcmp((const char *)headers.bytes+headers.length-4,end,4)==0) break;}
        NSString *text=[[NSString alloc] initWithData:headers encoding:NSUTF8StringEncoding]; NSUInteger expected=0;
        for(NSString *line in [text componentsSeparatedByString:@"\r\n"]){if([line.lowercaseString hasPrefix:@"content-length:"]) expected=[line substringFromIndex:15].integerValue;}
        NSUInteger received=0; char chunk[16384]; while(received<expected){ssize_t n=recv(fd,chunk,MIN(sizeof(chunk),expected-received),0); if(n<=0)break; received+=n; usleep(10000);}
        NSString *json=[NSString stringWithFormat:@"{\"received\":%lu}",(unsigned long)received]; NSData *body=[json dataUsingEncoding:NSUTF8StringEncoding];
        NSString *head=[NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n",(unsigned long)body.length]; NSData *headData=[head dataUsingEncoding:NSUTF8StringEncoding]; send(fd,headData.bytes,headData.length,0); send(fd,body.bytes,body.length,0);close(fd);close(listener);[served fulfill];
    });
    XBNetworkConfiguration *config=[XBNetworkConfiguration new];config.sessionConfiguration=[NSURLSessionConfiguration ephemeralSessionConfiguration];
    XBNetwork *network=[[XBNetwork alloc] initWithConfiguration:config];
    XBHTTPRequest *r=[XBHTTPRequest requestWithURLString:[NSString stringWithFormat:@"http://127.0.0.1:%u/upload",port] method:XBHTTPMethodPOST];
    r.body=[XBHTTPBody multipartBodyWithParameters:@{} fileParts:@[[XBHTTPFilePart partWithName:@"file" fileName:@"test.bin" MIMEType:@"application/octet-stream" data:[NSMutableData dataWithLength:2*1024*1024]]]];
    XCTestExpectation *done=[self expectationWithDescription:@"upload done"];__block NSUInteger progressCount=0;__block BOOL completed=NO;
    [network sendRequest:r uploadProgress:^(NSProgress *progress){XCTAssertFalse(completed);XCTAssertTrue(NSThread.isMainThread);XCTAssertGreaterThan(progress.completedUnitCount,0);progressCount++;} completion:^(id object,NSError *error){completed=YES;XCTAssertNil(error);XCTAssertGreaterThan([object[@"received"] unsignedIntegerValue],2u*1024u*1024u);XCTAssertGreaterThan(progressCount,0u);[done fulfill];}];
    [self waitForExpectations:@[done,served] timeout:8];[network invalidateAndCancel];
}
@end
