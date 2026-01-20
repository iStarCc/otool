import SwiftUI
import OTooliOS

/// 动态库分析器主视图
struct DylibAnalyzerView: View {
    @StateObject private var viewModel = DylibAnalyzerViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 顶部统计卡片
                    statsSection
                    
                    // 分析按钮
                    analyzeButton
                    
                    // 结果展示区域
                    if viewModel.isAnalyzing {
                        loadingView
                    } else if !viewModel.analysisResult.isEmpty {
                        resultSection
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .navigationTitle("Dylib 分析器")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.showSimpleView.toggle() }) {
                            Label(
                                viewModel.showSimpleView ? "详细视图" : "简洁视图",
                                systemImage: viewModel.showSimpleView ? "list.bullet" : "list.dash"
                            )
                        }
                        
                        Button(action: viewModel.shareReport) {
                            Label("分享报告", systemImage: "square.and.arrow.up")
                        }
                        .disabled(viewModel.analysisResult.isEmpty)
                        
                        Button(action: viewModel.copyToClipboard) {
                            Label("复制结果", systemImage: "doc.on.doc")
                        }
                        .disabled(viewModel.analysisResult.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $viewModel.shareItem) { item in
                ActivityView(activityItems: [item.text])
            }
            .alert("成功", isPresented: $viewModel.showCopyAlert) {
                Button("好的", role: .cancel) {}
            } message: {
                Text("已复制到剪贴板")
            }
        }
    }
    
    // MARK: - 统计卡片区域
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCardView(
                title: "依赖库",
                value: "\(viewModel.dylibCount)",
                icon: "link.circle.fill",
                color: .blue
            )
            
            StatCardView(
                title: "系统框架",
                value: "\(viewModel.frameworkCount)",
                icon: "square.stack.3d.up.fill",
                color: .green
            )
            
            StatCardView(
                title: "架构",
                value: viewModel.architecture,
                icon: "cpu",
                color: .orange
            )
        }
    }
    
    // MARK: - 分析按钮
    
    private var analyzeButton: some View {
        Button(action: viewModel.analyzeCurrentApp) {
            HStack {
                if viewModel.isAnalyzing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.title3)
                }
                Text(viewModel.isAnalyzing ? "分析中..." : "分析当前应用")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.blue, .blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(viewModel.isAnalyzing)
    }
    
    // MARK: - 加载视图
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在分析二进制文件...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("准备分析")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("点击上方按钮分析当前应用的动态库依赖")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 结果展示区域
    
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("分析结果")
                    .font(.headline)
                Spacer()
                if !viewModel.analysisResult.isEmpty {
                    Text("\(viewModel.dylibCount) 个依赖")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if viewModel.showSimpleView {
                simpleResultView
            } else {
                detailedResultView
            }
        }
    }
    
    private var simpleResultView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.libraries, id: \.self) { lib in
                    HStack {
                        Image(systemName: iconForLibrary(lib))
                            .foregroundColor(colorForLibrary(lib))
                            .frame(width: 24)
                        
                        Text(lib)
                            .font(.system(.footnote, design: .monospaced))
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                }
            }
            .padding()
        }
        .frame(maxHeight: 400)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var detailedResultView: some View {
        ScrollView {
            Text(viewModel.analysisResult)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding()
        }
        .frame(maxHeight: 400)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions
    
    private func iconForLibrary(_ lib: String) -> String {
        if lib.contains(".framework") {
            return "square.stack.3d.up"
        } else if lib.contains("/usr/lib/") {
            return "link"
        } else {
            return "doc"
        }
    }
    
    private func colorForLibrary(_ lib: String) -> Color {
        if lib.contains("/System/Library/") {
            return .blue
        } else if lib.contains("/usr/lib/swift") {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - 统计卡片视图

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - ActivityView (分享)

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

struct DylibAnalyzerView_Previews: PreviewProvider {
    static var previews: some View {
        DylibAnalyzerView()
    }
}
