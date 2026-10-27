# XBNetwork

Objective-C HTTP 组件，基于 `NSURLSession`，iOS 15+。明确区分 Query 和 Body，提供可配置公共参数、请求适配、上传进度、Cookie 隔离、传输总预算和结构化错误。

## 安装

在 Podfile 中使用发布标签：

```ruby
pod 'XBNetwork', :git => 'https://github.com/wxb74/XBNetwork.git', :tag => 'v0.1.0'
```

然后执行 `pod install`，打开 `.xcworkspace`。仓库发布不等于 CocoaPods 公共索引发布，目前请使用上面的 Git 方式。

组件仅依赖 `AFNetworking/Serialization ~> 4.0.1`，不使用 AFNetworking 的会话、网络监测或 UIKit 扩展。AFNetworking 已弃用；首版保留其参数编码行为，后续替换编码器前需要验证嵌套参数和 Multipart 字节兼容性。

Xcode 27.1 不再接受 AFNetworking 声明的 iOS 9 编译目标。使用该 SDK 时，在宿主现有 `post_install` 中合并以下处理（保留其他设置）：

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      minimum = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
      if minimum && Gem::Version.new(minimum) < Gem::Version.new('15.0')
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      end
    end
  end
end
```

Demo 已包含此设置和显式 Pods 构建依赖；无需拷贝外部源代码。

## 快速开始

```objc
#import <XBNetwork/XBNetworkUmbrella.h>

[XBNetwork GET:@"https://example.com/items"
    parameters:@{@"page": @1}
    completion:^(id object, NSError *error) {
        if (error) {
            NSLog(@"%@", XBNetworkErrorDisplayMessage(error, @"请求失败"));
            return;
        }
        // 默认在主队列回调。
    }];
```

共享入口使用默认配置。需要鉴权、公共参数或独立取消范围时创建实例：

```objc
XBNetworkConfiguration *configuration = [XBNetworkConfiguration new];
configuration.defaultHeaders = @{@"Accept": @"application/json"};
configuration.commonParametersProvider = ^NSDictionary *(XBHTTPRequest *request) {
    // 每次发送时读取宿主的当前状态。此处仅为示例。
    return @{@"platform": @"ios"};
};
configuration.requestAdapter = ^BOOL(XBHTTPRequest *request, NSError **error) {
    NSMutableDictionary *headers = [request.headers mutableCopy];
    headers[@"X-Client"] = @"example";
    request.headers = headers;
    return YES;
};
XBNetwork *network = [[XBNetwork alloc] initWithConfiguration:configuration];
[network POSTJSON:@"https://example.com/items"
        parameters:@{@"title": @"示例"}
        completion:^(id object, NSError *error) { }];
```

初始化时复制配置。Provider/Adapter 捕获宿主对象时应注意循环引用；动态字段可在 Block 内按请求读取。发送前在调用线程同步执行 Provider 和 Adapter，完成、进度回调异步投递到 `completionQueue`（默认主队列，建议使用串行队列）。组件不会自动读取用户、广告标识或设备信息。

## 显式请求与上传

```objc
XBHTTPRequest *request = [XBHTTPRequest requestWithURLString:@"https://example.com/upload"
                                                     method:XBHTTPMethodPOST];
request.queryParameters = @{@"folder": @"images"};
request.body = [XBHTTPBody multipartBodyWithParameters:@{@"caption": @"示例"}
                                           fileParts:@[
    [XBHTTPFilePart partWithName:@"file"
                       fileName:@"image.png"
                       MIMEType:@"image/png"
                           data:imageData]
]];
NSURLSessionTask *task = [network sendRequest:request
                             uploadProgress:^(NSProgress *progress) {
    // expected size 未知时 totalUnitCount 为 -1。
} detailedCompletion:^(XBHTTPResponse *response, NSError *error) {
    // response 提供状态码、响应头、原始字节、解析结果和传输耗时。
}];
// [task cancel];
```

支持 GET、POST、PUT、PATCH、DELETE、HEAD；Body 可选择 Form、JSON、Raw、Multipart。GET/HEAD 不允许 Body。JSON Body 根对象需为字典或数组。所有请求都要求完整的 HTTP/HTTPS URL。

## 行为约定

| 配置 | 行为 |
|---|---|
| 公共参数位置 | 便捷 GET 和 QueryJSON 使用 Query；Form、JSON 和 QueryForm 使用 Body。显式请求默认不合并，按 `commonParameterPlacement` 选择 |
| 参数优先级 | 显式参数覆盖同名公共参数；不包含任何 userid/userId 特例 |
| 请求头 | 单请求字段按大小写不敏感覆盖默认头；编码器生成的 Content-Type 保留；禁用 Cookie 时过滤 Cookie 头 |
| 超时 | `timeout <= 0` 使用配置默认值（20 秒）；`totalTimeout > 0` 额外限制整次传输时间；列表工厂为 8 秒等待、10 秒总预算 |
| 响应 | 默认接受 2xx 并解析 JSON；可选择 UTF-8 文本、NSData 和自定义状态码 |
| 空响应 | 默认报错；HEAD、204 等按接口设置 `allowsEmptyResponse = YES` |
| Cookie | 默认不读、不发、不保存系统 Cookie；System 模式使用独立会话及配置的 CookieStorage |
| 请求失败 | 统一 XBNetworkErrorDomain，保留 underlyingError；HTTP 错误在 userInfo 中保留响应、数据和可解析的 JSON |
| 回调 | 构建失败返回 nil，仍异步回调一次；超时、取消和网络结束通过同一完成门，只交付一次 |
| 取消范围 | task.cancel 只取消对应请求；实例 cancelAllRequests 只取消该实例；类方法只作用于 sharedNetwork |
| 关闭实例 | invalidateAndCancel 永久关闭此实例；再次发送返回取消错误。实例释放会关闭其会话，正在执行的请求由客户端持有到结束 |

发送前复制请求配置并同步编码，发送后改动原请求不会改变解析配置或已构建请求。JSON Body 对合法 JSON 做递归快照。请勿在另一个线程同时修改正在配置、复制或编码的可变对象。

`totalTimeout` 从客户端创建传输任务开始计算，不覆盖调用方自己的 Token 等待、Provider/Adapter 或之后的 UI 处理。总超时可能与网络完成竞争；以先进入完成门的结果为准。上传进度仅代表发送字节，不代表服务器已处理；排队进度在任务结束后被丢弃，不保证最后一次进度必为 100%。

## 日志

`configuration.logger` 默认为 nil。实现 `XBNetworkLogger` 可接收开始和结束事件。事件省略 Body，移除 URL 用户名、密码、Fragment，遮盖所有 Query 值和 Header 值；只包含方法、URL 路径及脱敏字段、状态码、耗时、错误码。日志回调可能发生在不同线程，接收端应保证线程安全，避免与持有它的 Network 形成循环引用。日志异常不会中断请求。URL 路径本身包含敏感内容时，宿主应进一步过滤或保持日志关闭。

完整响应和 NSError.userInfo 仍包含业务所需的原始请求/响应，调用方不应直接打印或上传这些原始对象。

## Demo 与测试

```sh
pod install
open XBNetworkDemo.xcworkspace
```

目录包含 18 个功能入口。前 17 项使用仅在 Demo 会话中生效的 `NSURLProtocol` 本地响应，不访问生产服务。最后一项验证真实上传进度：

```sh
python3 Demo/UploadServer.py
```

模拟器访问 `http://127.0.0.1:8765/upload`。真机需修改 Demo URL 为 Mac 的局域网地址，并自行选择监听地址。本地 HTTP 例外仅在 Demo 的 Info.plist 声明，不修改组件或宿主的 ATS 配置。

在 Xcode 中执行 Test。自动化测试的真实上传用例自行建立随机端口的回环 HTTP 服务，不需要额外启动 Python 服务。

完整 Pod 校验（在安装 CocoaPods 的 Ruby 环境执行）：

```sh
ruby Scripts/validate-pod.rb
```

该脚本只将验证临时工程的旧依赖最低编译版本抬到 iOS 15，保留 CocoaPods 的编译、链接和导入校验；`--allow-warnings` 用于第三方弃用告警。直接执行普通 `pod lib lint` 在拒绝 iOS 9 target 的 SDK 上会失败。

首版未提供文件下载落盘、断点续传、自动重试、Token 自动刷新、请求合并、业务数据缓存或证书固定策略。`NSURLRequestCachePolicy` 仅控制系统 URLCache；大文件上传目前以 NSData 提供文件数据。

## 从 CXNetwork 迁移

公开组件的类、文件、枚举、函数和错误域均使用 XB 前缀。请求构建器、解析器、会话客户端为内部头文件。

原业务可以保留 CXNetwork 薄适配层：继续处理 App 公共参数、旧错误域和调试日志，内部转换到 XB 请求发送。适配层及业务源码不随此仓库发布。新页面可直接使用 XBNetwork。旧 HttpErrorType/HttpRequestType 继续由原业务管理。

MIT License.
