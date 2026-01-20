# 更新日志

## [1.1.0] - 2026-01-20

### 新增功能

#### 🎯 智能解析

新增 `OTooliOS.parse(_:)` 方法，自动识别并解析 .app bundle 或可执行文件：

```swift
// 自动识别类型
let info = try OTooliOS.parse("/Applications/Calculator.app")  // .app bundle
let info = try OTooliOS.parse("/usr/bin/ls")                   // 可执行文件
```

#### 📦 .app Bundle 支持

- ✅ 支持解析 iOS/macOS .app bundle
- ✅ 自动读取 Info.plist 并查找主可执行文件
- ✅ 新增 `OTooliOS.parseAppBundle(_:)` - 解析 .app bundle
- ✅ 新增 `OTooliOS.getMainExecutablePath(from:)` - 获取主可执行文件路径
- ✅ 新增 `MachOParser.parseAuto(at:)` - 智能解析
- ✅ 新增 `MachOParser.parseAppBundle(at:)` - 解析 .app bundle

#### 🛠️ 命令行工具增强

命令行工具现在自动识别文件类型：

```bash
swift run otool-cli /Applications/Calculator.app
swift run otool-cli /usr/bin/ls
swift run otool-cli -v /path/to/MyApp.app
```

### 错误处理增强

新增 3 个专用错误类型：

- `notAnAppBundle` - 不是有效的 .app bundle
- `infoPlistNotFound` - Info.plist 文件未找到
- `executableNotFoundInPlist` - Info.plist 中未找到 CFBundleExecutable

### API 列表

#### 推荐使用

```swift
OTooliOS.parse(_:)                      // 智能解析（推荐）
```

#### 其他可用方法

```swift
OTooliOS.parseFile(_:)                  // 解析普通文件
OTooliOS.parseAppBundle(_:)             // 解析 .app bundle
OTooliOS.getMainExecutablePath(from:)   // 获取主可执行文件路径
OTooliOS.getDynamicLibraries(from:)     // 获取动态库列表
```

### 文档更新

- ✅ 精简文档数量，从 8 个减少到 3 个
- ✅ 合并 iOS 集成文档到 USAGE.md
- ✅ 更新所有示例代码使用新 API
- ✅ 添加完整的错误处理文档

### 测试

- ✅ 新增 8 个 .app bundle 相关测试
- ✅ 所有测试通过，无 linter 错误

### 兼容性

- ✅ 向后兼容，所有现有 API 保持不变
- ✅ 支持 iOS 15.0+、macOS 12.0+
- ✅ 支持 .app bundle、Fat Binary、32/64位应用
- ✅ 支持所有主流架构（ARM64、x86_64 等）

### 示例代码

查看 `Examples/` 目录：
- `AppBundleExample.swift` - 基本示例
- `DemoScript.swift` - 完整演示
- `iOSApp/` - iOS 集成示例

---

## [1.0.0] - 初始版本

### 核心功能

- ✅ 基本 Mach-O 文件解析
- ✅ 动态库依赖查看
- ✅ 命令行工具
- ✅ iOS/macOS 支持
- ✅ Fat Binary 支持
- ✅ 32/64 位架构支持

### 包含组件

- `MachOParser` - Mach-O 文件解析器
- `MachOStructs` - Mach-O 结构定义
- `DylibInfo` - 动态库信息
- `OTooliOS` - 公共 API
- `otool-cli` - 命令行工具
