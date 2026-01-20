# iOS 项目集成指南

本指南将帮助你在未越狱的 iOS Swift 项目中集成 OTool iOS 库。

## 集成方式

### 方式一：Swift Package Manager（推荐）

#### 1. 在 Xcode 中集成

1. 打开你的 iOS 项目
2. 选择 `File` → `Add Package Dependencies...`
3. 输入本仓库的 URL 或本地路径：`file:///Users/kcui/otool-ios`
4. 选择版本规则，点击 `Add Package`
5. 选择 `OTooliOS` 库添加到你的目标

#### 2. 在 Package.swift 中集成

如果你的项目本身是一个 Swift Package：

```swift
// Package.swift
dependencies: [
    .package(path: "../otool-ios")
    // 或者使用 URL
    // .package(url: "https://github.com/your-repo/otool-ios", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["OTooliOS"]
    )
]
```

### 方式二：手动集成

1. 将以下文件复制到你的项目：
   - `Sources/OTooliOS/MachOParser.swift`
   - `Sources/OTooliOS/MachOStructs.swift`
   - `Sources/OTooliOS/DylibInfo.swift`
   - `Sources/OTooliOS/OTooliOS.swift`

2. 在 Xcode 中添加这些文件到你的项目

## 在 iOS 应用中的使用场景

### ⚠️ 重要限制说明

在未越狱的 iOS 设备上，由于沙盒限制，你只能访问：

✅ **可以访问的文件：**
- 应用自身的可执行文件 (`Bundle.main.executablePath`)
- 应用 Bundle 内的框架和动态库
- 应用 Documents 目录下的文件
- 通过文件选择器用户主动选择的文件

❌ **无法访问的文件：**
- 系统库（如 `/usr/lib/libSystem.dylib`）
- 其他应用的文件
- 系统目录下的文件

### 实际应用场景

1. **查看自己应用的依赖** - 分析当前 App 依赖了哪些动态库
2. **检查第三方库** - 查看集成的 SDK 和框架的依赖关系
3. **安全审计** - 检查 App 是否包含不期望的依赖
4. **开发工具** - 作为开发辅助工具分析 dylib 文件

## 完整示例代码

### SwiftUI 示例

```swift
import SwiftUI
import OTooliOS

struct ContentView: View {
    @State private var analysisResult = ""
    @State private var isAnalyzing = false
    @State private var dylibCount = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 统计卡片
                HStack(spacing: 15) {
                    StatCard(
                        title: "依赖库数量",
                        value: "\(dylibCount)",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "架构",
                        value: architectureInfo,
                        color: .green
                    )
                }
                .padding()
                
                // 分析按钮
                Button(action: analyzeCurrentApp) {
                    HStack {
                        if isAnalyzing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "magnifyingglass.circle.fill")
                        }
                        Text(isAnalyzing ? "分析中..." : "分析当前应用")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isAnalyzing)
                .padding(.horizontal)
                
                // 结果展示
                ScrollView {
                    if analysisResult.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("点击按钮分析应用依赖")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 60)
                    } else {
                        Text(analysisResult)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .navigationTitle("OTool iOS")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var architectureInfo: String {
        #if arch(arm64)
        return "ARM64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "Unknown"
        #endif
    }
    
    private func analyzeCurrentApp() {
        isAnalyzing = true
        
        // 在后台线程执行分析
        DispatchQueue.global(qos: .userInitiated).async {
            guard let executablePath = Bundle.main.executablePath else {
                DispatchQueue.main.async {
                    analysisResult = "❌ 无法获取应用可执行文件路径"
                    isAnalyzing = false
                }
                return
            }
            
            do {
                let info = try OTooliOS.parseFile(executablePath)
                
                DispatchQueue.main.async {
                    dylibCount = info.dynamicLibraries.count
                    analysisResult = info.detailedOutput
                    isAnalyzing = false
                }
            } catch {
                DispatchQueue.main.async {
                    analysisResult = "❌ 解析失败: \(error.localizedDescription)"
                    isAnalyzing = false
                }
            }
        }
    }
}

// 统计卡片组件
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
```

### UIKit 示例

```swift
import UIKit
import OTooliOS

class DylibAnalyzerViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let analyzeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("分析当前应用", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let resultTextView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        label.text = "0"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let countTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .center
        label.text = "动态库依赖"
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = "Dylib 分析器"
        view.backgroundColor = .systemBackground
        
        // 添加子视图
        view.addSubview(countLabel)
        view.addSubview(countTitleLabel)
        view.addSubview(analyzeButton)
        view.addSubview(resultTextView)
        view.addSubview(activityIndicator)
        
        // 设置约束
        NSLayoutConstraint.activate([
            countLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            countLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            countTitleLabel.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 4),
            countTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            analyzeButton.topAnchor.constraint(equalTo: countTitleLabel.bottomAnchor, constant: 20),
            analyzeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            analyzeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            analyzeButton.heightAnchor.constraint(equalToConstant: 50),
            
            resultTextView.topAnchor.constraint(equalTo: analyzeButton.bottomAnchor, constant: 20),
            resultTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            resultTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            activityIndicator.centerXAnchor.constraint(equalTo: analyzeButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: analyzeButton.centerYAnchor)
        ])
        
        // 添加按钮事件
        analyzeButton.addTarget(self, action: #selector(analyzeTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func analyzeTapped() {
        startAnalyzing()
    }
    
    private func startAnalyzing() {
        analyzeButton.isEnabled = false
        activityIndicator.startAnimating()
        analyzeButton.setTitle("", for: .normal)
        resultTextView.text = ""
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performAnalysis()
        }
    }
    
    private func performAnalysis() {
        guard let executablePath = Bundle.main.executablePath else {
            DispatchQueue.main.async { [weak self] in
                self?.showError("无法获取应用可执行文件路径")
            }
            return
        }
        
        do {
            let info = try OTooliOS.parseFile(executablePath)
            
            DispatchQueue.main.async { [weak self] in
                self?.displayResults(info)
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.showError("解析失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func displayResults(_ info: MachOInfo) {
        countLabel.text = "\(info.dynamicLibraries.count)"
        resultTextView.text = info.detailedOutput
        
        analyzeButton.setTitle("重新分析", for: .normal)
        analyzeButton.isEnabled = true
        activityIndicator.stopAnimating()
        
        // 添加动画效果
        UIView.animate(withDuration: 0.3) {
            self.countLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.countLabel.transform = .identity
            }
        }
    }
    
    private func showError(_ message: String) {
        resultTextView.text = "❌ \(message)"
        analyzeButton.setTitle("分析当前应用", for: .normal)
        analyzeButton.isEnabled = true
        activityIndicator.stopAnimating()
    }
}
```

### 实用工具类

```swift
import Foundation
import OTooliOS

/// 动态库分析工具类
class DylibAnalyzer {
    
    /// 单例
    static let shared = DylibAnalyzer()
    
    private init() {}
    
    /// 分析当前应用
    func analyzeCurrentApp() -> Result<MachOInfo, Error> {
        guard let path = Bundle.main.executablePath else {
            return .failure(AnalyzerError.executableNotFound)
        }
        
        do {
            let info = try OTooliOS.parseFile(path)
            return .success(info)
        } catch {
            return .failure(error)
        }
    }
    
    /// 检查是否包含特定依赖
    func containsDependency(named name: String) -> Bool {
        guard case .success(let info) = analyzeCurrentApp() else {
            return false
        }
        
        return info.dynamicLibraries.contains { $0.path.contains(name) }
    }
    
    /// 获取所有系统框架
    func getSystemFrameworks() -> [String] {
        guard case .success(let info) = analyzeCurrentApp() else {
            return []
        }
        
        return info.dynamicLibraries
            .map { $0.path }
            .filter { $0.contains("/System/Library/Frameworks/") }
            .compactMap { path in
                let components = path.components(separatedBy: "/")
                return components.first { $0.hasSuffix(".framework") }
            }
    }
    
    /// 获取第三方库
    func getThirdPartyLibraries() -> [String] {
        guard case .success(let info) = analyzeCurrentApp() else {
            return []
        }
        
        return info.dynamicLibraries
            .map { $0.path }
            .filter { !$0.contains("/System/Library/") && !$0.contains("/usr/lib/") }
    }
    
    /// 生成依赖报告
    func generateReport() -> String {
        guard case .success(let info) = analyzeCurrentApp() else {
            return "无法生成报告"
        }
        
        var report = """
        📱 应用依赖分析报告
        ═══════════════════════════════════
        
        📊 基本信息
        - 架构: \(info.architecture)
        - 位数: \(info.is64Bit ? "64位" : "32位")
        - 总依赖数: \(info.dynamicLibraries.count)
        
        """
        
        let frameworks = getSystemFrameworks()
        let thirdParty = getThirdPartyLibraries()
        let systemLibs = info.dynamicLibraries.filter { $0.path.hasPrefix("/usr/lib/") }
        
        report += """
        
        🔹 系统框架 (\(frameworks.count))
        \(frameworks.map { "  • \($0)" }.joined(separator: "\n"))
        
        🔹 系统库 (\(systemLibs.count))
        \(systemLibs.map { "  • \($0.path.components(separatedBy: "/").last ?? $0.path)" }.joined(separator: "\n"))
        
        """
        
        if !thirdParty.isEmpty {
            report += """
            
            🔹 第三方库 (\(thirdParty.count))
            \(thirdParty.map { "  • \($0)" }.joined(separator: "\n"))
            
            """
        }
        
        return report
    }
}

enum AnalyzerError: Error, LocalizedError {
    case executableNotFound
    
    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "无法找到应用可执行文件"
        }
    }
}

/// 使用示例
func example() {
    let analyzer = DylibAnalyzer.shared
    
    // 检查是否使用了 Swift
    if analyzer.containsDependency(named: "swift") {
        print("应用使用了 Swift 运行时")
    }
    
    // 获取系统框架
    let frameworks = analyzer.getSystemFrameworks()
    print("系统框架: \(frameworks)")
    
    // 生成报告
    let report = analyzer.generateReport()
    print(report)
}
```

## 高级用法

### 1. 分析应用 Bundle 中的框架

```swift
func analyzeFramework(named frameworkName: String) -> Result<MachOInfo, Error> {
    guard let bundlePath = Bundle.main.bundlePath else {
        return .failure(AnalyzerError.executableNotFound)
    }
    
    let frameworkPath = "\(bundlePath)/Frameworks/\(frameworkName).framework/\(frameworkName)"
    
    do {
        let info = try OTooliOS.parseFile(frameworkPath)
        return .success(info)
    } catch {
        return .failure(error)
    }
}
```

### 2. 比较不同版本的依赖变化

```swift
class DependencyComparator {
    func compare(oldDeps: [String], newDeps: [String]) -> (added: [String], removed: [String]) {
        let oldSet = Set(oldDeps)
        let newSet = Set(newDeps)
        
        let added = Array(newSet.subtracting(oldSet))
        let removed = Array(oldSet.subtracting(newSet))
        
        return (added, removed)
    }
}
```

### 3. 导出分析结果

```swift
func exportAnalysis(info: MachOInfo, to url: URL) throws {
    let json: [String: Any] = [
        "architecture": info.architecture,
        "is64bit": info.is64Bit,
        "fileType": info.fileType,
        "rpaths": info.rpaths,
        "libraries": info.dynamicLibraries.map { [
            "path": $0.path,
            "currentVersion": $0.currentVersion,
            "compatibilityVersion": $0.compatibilityVersion,
            "loadType": $0.loadType.rawValue
        ]}
    ]
    
    let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
    try jsonData.write(to: url)
}
```

## 性能优化建议

1. **异步处理** - 始终在后台线程执行文件解析
2. **缓存结果** - 如果需要多次访问，缓存 `MachOInfo` 对象
3. **延迟加载** - 只在需要时才执行分析

## 注意事项

1. ⚠️ 文件访问受沙盒限制
2. ⚠️ 大文件解析可能需要时间，使用异步处理
3. ⚠️ 确保处理错误情况，文件可能不存在或格式错误
4. ⚠️ 在真机测试前确保签名和权限配置正确

## 调试技巧

```swift
#if DEBUG
// 打印可用的路径进行测试
func printAvailablePaths() {
    print("Bundle Path:", Bundle.main.bundlePath)
    print("Executable Path:", Bundle.main.executablePath ?? "N/A")
    print("Frameworks Path:", Bundle.main.privateFrameworksPath ?? "N/A")
}
#endif
```

## 常见问题

**Q: 为什么无法访问系统库？**
A: 未越狱的 iOS 设备受沙盒限制，只能访问应用自己的文件。

**Q: 如何测试这个库？**
A: 使用 `Bundle.main.executablePath` 分析当前应用，或者在模拟器上测试。

**Q: 可以分析从网络下载的 dylib 文件吗？**
A: 可以，只要文件保存在应用的沙盒目录内（如 Documents 目录）。

## 完整的示例项目结构

```
MyApp/
├── App/
│   ├── MyApp.swift
│   └── ContentView.swift
├── Features/
│   ├── DylibAnalyzer/
│   │   ├── DylibAnalyzerView.swift
│   │   ├── DylibAnalyzerViewModel.swift
│   │   └── DylibAnalyzer.swift
│   └── ...
└── Package Dependencies/
    └── OTooliOS
```

按照本指南，你就可以在未越狱的 iOS 项目中成功集成和使用 OTool iOS 库了！🎉
