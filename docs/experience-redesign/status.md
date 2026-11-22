# 实现状态与证据

更新到分支 `cursor/experience-redesign-b975`。这里只写已经发生的事。设计目标见 [规格](README.md)。计划中的项不记成完成。

## 提交

| 提交 | 内容 |
| --- | --- |
| `fa7314c` | 石墨朱红主题、四栏壳、启动页原标、搜索聚合状态、片库分段、`autoAdvance`、电视线路面板的第一版 |
| `57f55cf` | 播放底栏（锁屏、弹幕、换源、选集、倍速）、电视按键命令测试、只在 pull request 上跑的检查工作流 |

工作区里还有尚未提交的发现默认站源、空状态文案、分类去重和管理摘要。那些在提交并装到模拟器之前，不算已实现。

## 设计目标对照

| 项 | 状态 | 说明 |
| --- | --- | --- |
| 原 Logo | 已实现 | 使用 `scripts/brand_icon_master.png`。启动页、侧栏和管理角标引用原图 |
| 深色石墨与浅色暖纸 token | 已实现，浅色未在模拟器验证 | `lib/ui/theme/palette.dart`，`app_theme.dart` |
| 状态色独立于品牌色 | 已实现于组件 | 搜索横幅和下载行。模拟器上还没拍到失败/验证的真实结果 |
| 手机四栏 | 已实现，模拟器已看到 | 发现、搜索、片库、管理。底栏有文字和圆点 |
| 电视左栏 | 代码已实现 | 没有电视系统镜像，没有遥控器实机 |
| 桌面侧栏换原标 | 已实现于代码 | 未在桌面窗口验证 |
| 发现宽幅主视觉 | 代码已改 `ExploreHero` | 模拟器首次打开仍落到「网盘分享」，目录为空，所以主视觉和海报没有在真机界面上出现 |
| 搜索一级与聚合 | 已实现，模拟器已看到空查询态 | 文案含「按站源保留结果，同名不合并」和「13 个站源」。没有用真实关键词打出部分失败 |
| 片库分段 | 已实现，模拟器已看到空的继续看 | 追剧、历史、下载分段存在。没有真实进度和下载任务 |
| 管理分组 | 部分实现 | `57f55cf` 的管理首页把每个站源铺成一行，网盘和主题被挤到屏外。这是已知差距 |
| 播放底栏 | 代码在 `57f55cf` | 模拟器还没打开播放器，手势和弹层没有实机证据 |
| `autoAdvance` | 已实现，单元测试通过 | 关闭后完播停在当前集；改倍速不会把开关写回去 |
| 电视按键表 | 纯函数测试通过 | 不是电视设备上的焦点走查 |
| 边缘 24pt 不抢返回 | 单元测试覆盖判定函数 | 没有在系统返回手势上实机确认 |

## 已验证

本地，Flutter 3.47.9：

- `57f55cf` 之前：两组 `flutter test --dart-define=DISABLE_REMOTE_IMAGES=true`（含 `ONLY_HONGGUO`）各 178 通过。
- 工作区新增发现站源测试后：同样两组各 180 通过。`dart analyze --fatal-infos lib test` 无问题。
- `native/` 的 `go test -race ./...` 在第一轮通过。站源列表增加 `allowEmptyCatalog` 之后，要以新的 APK 构建日志为准，那次构建还在进行。

模拟器（Android 34，`sdk_gphone64_x86_64`，KVM）：

- 2026-11-22 约 09:01 UTC，安装并启动了 **Debug 签名** 的 `gomovie-1.0.0+123-x86_64.apk`。
- 包名 `com.gomovie.app`。`adb install` 成功。前台是 `com.gomovie.app/com.gomovie.MainActivity`。
- 截图：
  - `emulator-phone-launch.png`：发现页站源是「网盘分享」，顶上两个「全部」，中间是「这里还没有剧」。
  - `emulator-phone-search.png`：搜索一级，聚合空状态。
  - `emulator-phone-library.png`：片库「继续看」空状态，分段可见。
  - `emulator-phone-manage.png`：站源逐行铺开，原 Logo 在角上。网盘、主题、备份不在首屏。

这些截图证明壳和模块加载，也证明发现和管理还没达到规格。

夹具渲染只写出一张深色发现构图 `phone-discover-dark.png`。浅色下一屏卡在第二次 `pumpWidget`，进程被 50 秒超时杀掉（退出码 124）。不再把 widget 金图当成运行证据。

## 包与签名

2026-11-22 08:55 UTC 的构建退出码 0。脚本是 `python3 scripts/build_android.py`，ABI 为 `arm64-v8a`、`armeabi-v7a`、`x86_64`。日志确认 14 个模块打进 Go 核心，包内有 `libgomovie_core.so` 和 `libmpv.so`。

签名证书是 Android Debug，`CN=Android Debug`。没有读取或使用发布 keystore。这个包不能覆盖正式证书安装的应用。

`versionName` 是 `1.0.0`。split APK 的 `versionCode` 在基础号 123 上加了 ABI 前缀：v7a 1123，arm64 2123，x86_64 4123。

这次包对应的是播放底栏提交前后的工作区，不包含后来的发现默认站源修改。新代码需要等当前重建结束再装。

正式签名路径仍是手动工作流 `.github/workflows/build.yml` 里的 `SIGNING_KEYSTORE_*` Secrets。该工作流不会在 pull request 上自动跑，本文也不触发它。

## 检查

`fa7314c` 上没有 check run，因为当时只有手动 `workflow_dispatch` 的 `build.yml`。

`57f55cf` 推送后，`PR checks` 工作流已创建运行：<https://github.com/feyakit/GoMovie/actions/runs/45005470525>。写本文时它仍在进行，结论还没有。

## 明确没验证

- 真实 media_kit 解码、暂停、seek、换集、退出释放。准备了本机生成的两段 4 秒测试片，还没有在新包里播。
- 电视系统镜像。`sdkmanager` 对 `system-images;android-34;android-tv;x86_64` 返回找不到包。没有 D-pad 实机。
- 播放器手势、横竖屏、弹层视觉。
- 浅色主题、详情海报、有数据时的发现主视觉。
- iOS。当前环境是 Linux，没有 Xcode，也没有描述文件或 p12。未签名 IPA 不能装 iPhone。
- 正式证书覆盖安装。
