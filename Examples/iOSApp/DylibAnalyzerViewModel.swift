import SwiftUI
import OTooliOS
import Combine

/// 动态库分析器视图模型
class DylibAnalyzerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var analysisResult = ""
    @Published var isAnalyzing = false
    @Published var dylibCount = 0
    @Published var frameworkCount = 0
    @Published var architecture = "-"
    @Published var libraries: [String] = []
    @Published var showSimpleView = false
    @Published var shareItem: ShareItem?
    @Published var showCopyAlert = false
    
    // MARK: - Private Properties
    
    private var machOInfo: MachOInfo?
    
    // MARK: - Public Methods
    
    /// 分析当前应用
    func analyzeCurrentApp() {
        isAnalyzing = true
        analysisResult = ""
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performAnalysis()
        }
    }
    
    /// 分享报告
    func shareReport() {
        guard !analysisResult.isEmpty else { return }
        
        let report = generateFullReport()
        shareItem = ShareItem(text: report)
    }
    
    /// 复制到剪贴板
    func copyToClipboard() {
        guard !analysisResult.isEmpty else { return }
        
        UIPasteboard.general.string = analysisResult
        showCopyAlert = true
    }
    
    // MARK: - Private Methods
    
    private func performAnalysis() {
        guard let executablePath = Bundle.main.executablePath else {
            DispatchQueue.main.async { [weak self] in
                self?.handleError("无法获取应用可执行文件路径")
            }
            return
        }
        
        do {
            let info = try OTooliOS.parseFile(executablePath)
            
            DispatchQueue.main.async { [weak self] in
                self?.processResults(info)
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.handleError("解析失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func processResults(_ info: MachOInfo) {
        machOInfo = info
        
        // 更新统计数据
        dylibCount = info.dynamicLibraries.count
        architecture = info.architecture
        
        // 计算框架数量
        frameworkCount = info.dynamicLibraries.filter {
            $0.path.contains(".framework")
        }.count
        
        // 提取库路径列表
        libraries = info.dynamicLibraries.map { $0.path }
        
        // 生成详细输出
        analysisResult = info.detailedOutput
        
        // 停止加载动画
        isAnalyzing = false
        
        // 添加触觉反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func handleError(_ message: String) {
        analysisResult = "❌ \(message)"
        isAnalyzing = false
        dylibCount = 0
        frameworkCount = 0
        libraries = []
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    private func generateFullReport() -> String {
        guard let info = machOInfo else {
            return analysisResult
        }
        
        var report = """
        📱 iOS 应用依赖分析报告
        ═══════════════════════════════════
        
        📊 基本信息
        • 应用名称: \(Bundle.main.displayName ?? "未知")
        • Bundle ID: \(Bundle.main.bundleIdentifier ?? "未知")
        • 版本: \(Bundle.main.version ?? "未知") (\(Bundle.main.buildNumber ?? "未知"))
        • 架构: \(info.architecture)
        • 位数: \(info.is64Bit ? "64位" : "32位")
        • 文件类型: \(info.fileType)
        
        """
        
        // 统计信息
        let systemFrameworks = libraries.filter {
            $0.contains("/System/Library/Frameworks/")
        }
        let systemLibs = libraries.filter {
            $0.hasPrefix("/usr/lib/") && !$0.contains("swift")
        }
        let swiftLibs = libraries.filter {
            $0.contains("/usr/lib/swift/")
        }
        let thirdParty = libraries.filter {
            !$0.contains("/System/Library/") && !$0.hasPrefix("/usr/lib/")
        }
        
        report += """
        📈 依赖统计
        • 总依赖数: \(dylibCount)
        • 系统框架: \(systemFrameworks.count)
        • 系统库: \(systemLibs.count)
        • Swift 库: \(swiftLibs.count)
        • 第三方库: \(thirdParty.count)
        
        """
        
        // RPath 信息
        if !info.rpaths.isEmpty {
            report += """
            🔍 RPath 信息
            \(info.rpaths.map { "• \($0)" }.joined(separator: "\n"))
            
            """
        }
        
        // 详细依赖列表
        report += """
        📦 系统框架 (\(systemFrameworks.count))
        \(systemFrameworks.map { "• \(extractFrameworkName($0))" }.joined(separator: "\n"))
        
        🔗 系统库 (\(systemLibs.count))
        \(systemLibs.map { "• \($0.components(separatedBy: "/").last ?? $0)" }.joined(separator: "\n"))
        
        """
        
        if !swiftLibs.isEmpty {
            report += """
            🦅 Swift 运行时库 (\(swiftLibs.count))
            \(swiftLibs.map { "• \($0.components(separatedBy: "/").last ?? $0)" }.joined(separator: "\n"))
            
            """
        }
        
        if !thirdParty.isEmpty {
            report += """
            📦 第三方库 (\(thirdParty.count))
            \(thirdParty.map { "• \($0)" }.joined(separator: "\n"))
            
            """
        }
        
        report += """
        
        ───────────────────────────────────
        生成时间: \(Date().formatted())
        生成工具: OTool iOS v1.0.0
        """
        
        return report
    }
    
    private func extractFrameworkName(_ path: String) -> String {
        let components = path.components(separatedBy: "/")
        if let framework = components.first(where: { $0.hasSuffix(".framework") }) {
            return framework.replacingOccurrences(of: ".framework", with: "")
        }
        return path
    }
}

// MARK: - ShareItem

struct ShareItem: Identifiable {
    let id = UUID()
    let text: String
}

// MARK: - Bundle Extension

extension Bundle {
    var displayName: String? {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
        object(forInfoDictionaryKey: "CFBundleName") as? String
    }
    
    var version: String? {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
    
    var buildNumber: String? {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
}
