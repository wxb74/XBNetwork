# Changelog

## 未发布

- 补全所有公开接口的中文注释，说明默认值、参数位置与优先级、线程、返回值和失败行为。
- 增加中文使用指南、接口选择表，以及完整响应、取消、错误处理和日志接入示例。
- 补充请求准备、Cookie 隔离、完成去重、总超时和响应解析的实现注释。
- 此次仅更新注释和文档，不修改请求行为、公开接口或 0.1.0 发布标签。

## 0.1.0 — 2026-10-27

- Extract configurable Objective-C HTTP requests into XBNetwork.
- Add explicit Query/Form/JSON/Raw/Multipart bodies, isolated Cookie sessions and response metadata.
- Support per-instance configuration, parameter providers, request adapters and scoped cancellation.
- Enforce one completion for deadline/transport races and suppress stale upload callbacks.
- Provide opt-in redacted logger, 18 Demo entries and deterministic plus real-loopback tests.
- Package AFNetworking serialization through CocoaPods and document modern SDK deployment compatibility.
