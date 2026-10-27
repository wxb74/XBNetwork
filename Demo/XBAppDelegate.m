#import <UIKit/UIKit.h>
#import <XBNetwork/XBNetworkUmbrella.h>
#import "XBDemoURLProtocol.h"
#import "XBDemoCatalog.h"

@interface XBDemoWeakLogger : NSObject <XBNetworkLogger>
@property (nonatomic, weak) id<XBNetworkLogger> target;
@end
@implementation XBDemoWeakLogger
- (void)networkDidRecordEvent:(NSDictionary *)event { [self.target networkDidRecordEvent:event]; }
@end
@interface XBDemoScreen : UIViewController <XBNetworkLogger>
@property (nonatomic) NSInteger example;
@property (nonatomic, strong) UITextView *output;
@property (nonatomic, strong) XBNetwork *network;
@property (nonatomic, strong) XBNetwork *otherNetwork;
@property (nonatomic, strong) NSURLSessionTask *task;
@property (nonatomic, strong) UIProgressView *progress;
@end
@implementation XBDemoScreen
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"运行" style:UIBarButtonItemStylePlain target:self action:@selector(run)];
    self.output = [UITextView new]; self.output.editable = NO; self.output.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular]; self.output.translatesAutoresizingMaskIntoConstraints = NO;
    self.progress = [UIProgressView new]; self.progress.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.output]; [self.view addSubview:self.progress];
    [NSLayoutConstraint activateConstraints:@[[self.progress.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],[self.progress.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],[self.progress.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],[self.output.topAnchor constraintEqualToAnchor:self.progress.bottomAnchor constant:12],[self.output.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],[self.output.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],[self.output.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]]];
    self.output.text = self.example == 17 ? @"连接 Demo/UploadServer.py 启动的本地服务器后，点击运行。真实 URLSession 发送上传字节，进度条显示 didSendBodyData。模拟器默认 http://127.0.0.1:8765/upload；真机需改为 Mac 局域网地址。" : @"点击右上角运行。使用本地模拟响应，可离线查看请求编码、响应和错误。上传进度请进入目录最后一项，使用真实本地 HTTP 传输验证。";
}
- (void)append:(NSString *)text { dispatch_async(dispatch_get_main_queue(), ^{ self.output.text = [self.output.text stringByAppendingFormat:@"%@\n",text]; }); }
- (void)networkDidRecordEvent:(NSDictionary *)event { [self append:[NSString stringWithFormat:@"脱敏日志：%@",event]]; }
- (void)send:(XBHTTPRequest *)request using:(XBNetwork *)network {
    __weak typeof(self) weakSelf = self;
    self.task = [network sendRequest:request uploadProgress:^(NSProgress *progress) {
        weakSelf.progress.progress = progress.fractionCompleted;
    } detailedCompletion:^(XBHTTPResponse *response, NSError *error) {
        if (error) [weakSelf append:[NSString stringWithFormat:@"错误 %@ / %ld：%@",error.domain,(long)error.code,error.localizedDescription]];
        else [weakSelf append:[NSString stringWithFormat:@"HTTP %ld，耗时 %.3fs\n%@",(long)response.HTTPResponse.statusCode,response.duration,response.responseObject ?: @"<空响应>"]];
    }];
}
- (void)run {
    [self.network invalidateAndCancel]; [self.otherNetwork invalidateAndCancel]; self.output.text = @""; self.progress.progress = 0;
    XBNetworkConfiguration *config = [XBNetworkConfiguration new];
    config.sessionConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.sessionConfiguration.protocolClasses = @[XBDemoURLProtocol.class];
    if (self.example == 14) {
        config.commonParametersProvider = ^NSDictionary *(XBHTTPRequest *request) { return @{@"platform":@"ios",@"account":@"demo"}; };
        config.requestAdapter = ^BOOL(XBHTTPRequest *request, NSError **error) { NSMutableDictionary *headers = [request.headers mutableCopy]; headers[@"X-Demo-Adapter"] = @"enabled"; request.headers = headers; return YES; };
    }
    if (self.example == 15) { XBDemoWeakLogger *logger = [XBDemoWeakLogger new]; logger.target = self; config.logger = logger; }
    if (self.example == 17) { config.sessionConfiguration.protocolClasses = @[]; config.defaultTimeout = 30; }
    self.network = [[XBNetwork alloc] initWithConfiguration:config];
    XBHTTPRequest *r = [XBHTTPRequest requestWithURLString:@"https://demo.xbnetwork.invalid/echo" method:XBHTTPMethodGET];
    r.queryParameters = @{@"keyword":@"中文 & + /",@"items":@[@"a",@"b"]}; r.headers = @{@"X-Demo":@"hello"};
    if (self.example == 1 || self.example == 4) { r.method = XBHTTPMethodPOST; r.body = [XBHTTPBody formBodyWithParameters:@{@"title":@"中文表单",@"count":@2}]; }
    if (self.example == 2 || self.example == 3) { r.method = XBHTTPMethodPOST; r.body = [XBHTTPBody JSONBodyWithJSONObject:@{@"title":@"JSON",@"items":@[@1,@2]}]; }
    if (self.example == 1 || self.example == 2) r.queryParameters = @{};
    if (self.example == 5) {
        for (NSUInteger method = XBHTTPMethodPUT; method <= XBHTTPMethodHEAD; method++) { XBHTTPRequest *v = [r copy]; v.method = method; if (method == XBHTTPMethodHEAD) v.allowsEmptyResponse = YES; [self send:v using:self.network]; }
        return;
    }
    if (self.example == 6) { r.method = XBHTTPMethodPOST; r.body = [XBHTTPBody rawBodyWithData:[@"plain body" dataUsingEncoding:NSUTF8StringEncoding] contentType:@"text/plain"]; }
    if (self.example == 7 || self.example == 17) {
        r.method = XBHTTPMethodPOST;
        NSData *bytes = self.example == 17 ? [NSMutableData dataWithLength:2*1024*1024] : [@"Demo file" dataUsingEncoding:NSUTF8StringEncoding];
        r.body = [XBHTTPBody multipartBodyWithParameters:@{@"caption":@"demo"} fileParts:@[[XBHTTPFilePart partWithName:@"file" fileName:@"sample.txt" MIMEType:@"text/plain" data:bytes]]];
        if (self.example == 17) r.URLString = @"http://127.0.0.1:8765/upload";
    }
    if (self.example == 8) { r.URLString = @"https://demo.xbnetwork.invalid/text"; r.responseType = XBHTTPResponseTypeString; [self send:r using:self.network]; r = [r copy]; r.URLString = @"https://demo.xbnetwork.invalid/binary"; r.responseType = XBHTTPResponseTypeData; }
    if (self.example == 9) { r.URLString = @"https://demo.xbnetwork.invalid/status/500"; [self send:r using:self.network]; r = [r copy]; r.URLString = @"https://demo.xbnetwork.invalid/invalid"; }
    if (self.example == 10) { r.URLString = @"https://demo.xbnetwork.invalid/empty"; [self send:r using:self.network]; r = [r copy]; r.allowsEmptyResponse = YES; }
    if (self.example == 11 || self.example == 12 || self.example == 16) r.URLString = @"https://demo.xbnetwork.invalid/slow";
    if (self.example == 11) r.totalTimeout = 0.05;
    if (self.example == 13) { r.headers = @{@"Cookie":@"demo=enabled"}; [self send:r using:self.network]; r = [r copy]; r.cookiePolicy = XBHTTPCookiePolicySystem; }
    if (self.example == 14) r.commonParameterPlacement = XBCommonParameterPlacementQuery;
    if (self.example == 15) { r.queryParameters = @{@"token":@"demo-secret"}; r.headers = @{@"Authorization":@"Bearer demo-secret"}; }
    [self send:r using:self.network];
    if (self.example == 12) [self.task cancel];
    if (self.example == 16) { self.otherNetwork = [[XBNetwork alloc] initWithConfiguration:config]; [self send:r using:self.otherNetwork]; [self.network cancelAllRequests]; }
}
- (void)dealloc { [_network invalidateAndCancel]; [_otherNetwork invalidateAndCancel]; }
@end

@interface XBCatalogController : UITableViewController
@end
@implementation XBCatalogController
- (void)viewDidLoad { [super viewDidLoad]; self.title = @"XBNetwork 示例"; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return XBDemoCatalog.titles.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil]; cell.textLabel.text = XBDemoCatalog.titles[indexPath.row]; cell.detailTextLabel.text = indexPath.row == 17 ? @"本地服务器 · 真实传输" : @"本地模拟 · 可离线运行"; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    XBDemoScreen *screen = [XBDemoScreen new]; screen.example = indexPath.row; screen.title = XBDemoCatalog.titles[indexPath.row]; [self.navigationController pushViewController:screen animated:YES];
}
@end
@interface XBAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation XBAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    return YES;
}
@end
int main(int argc, char *argv[]) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(XBAppDelegate.class)); } }

@interface XBSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation XBSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    if (![scene isKindOfClass:UIWindowScene.class]) return;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[XBCatalogController new]];
    [self.window makeKeyAndVisible];
}
@end
