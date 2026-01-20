.PHONY: build test clean run install help

# 默认目标
.DEFAULT_GOAL := help

# 变量
SWIFT_BUILD = swift build
SWIFT_TEST = swift test
SWIFT_RUN = swift run
BUILD_DIR = .build
PRODUCT_NAME = otool-cli

# 帮助信息
help: ## 显示帮助信息
	@echo "OTool iOS - Makefile 命令"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

# 构建
build: ## 构建项目 (debug)
	@echo "🔨 构建项目..."
	@$(SWIFT_BUILD)
	@echo "✅ 构建完成"

build-release: ## 构建项目 (release)
	@echo "🔨 构建项目 (Release)..."
	@$(SWIFT_BUILD) -c release
	@echo "✅ Release 构建完成"

# 测试
test: ## 运行测试
	@echo "🧪 运行测试..."
	@$(SWIFT_TEST)
	@echo "✅ 测试完成"

# 运行命令行工具
run: ## 运行命令行工具（需要提供文件路径）
	@echo "🚀 运行 otool-cli..."
	@$(SWIFT_RUN) $(PRODUCT_NAME) $(ARGS)

# 示例运行
run-example: ## 运行示例（解析 /usr/lib/libSystem.dylib）
	@echo "🚀 运行示例..."
	@$(SWIFT_RUN) $(PRODUCT_NAME) /usr/lib/libSystem.dylib

run-verbose: ## 运行详细模式示例
	@echo "🚀 运行详细模式..."
	@$(SWIFT_RUN) $(PRODUCT_NAME) -v /usr/lib/libSystem.dylib

# 清理
clean: ## 清理构建文件
	@echo "🧹 清理构建文件..."
	@rm -rf $(BUILD_DIR)
	@echo "✅ 清理完成"

# 安装（复制到 /usr/local/bin）
install: build-release ## 安装到系统（需要 sudo）
	@echo "📦 安装 otool-cli..."
	@sudo cp $(BUILD_DIR)/release/$(PRODUCT_NAME) /usr/local/bin/
	@echo "✅ 安装完成: /usr/local/bin/$(PRODUCT_NAME)"

# 卸载
uninstall: ## 从系统卸载
	@echo "🗑️  卸载 otool-cli..."
	@sudo rm -f /usr/local/bin/$(PRODUCT_NAME)
	@echo "✅ 卸载完成"

# 格式化代码
format: ## 格式化代码（需要 swift-format）
	@if command -v swift-format >/dev/null 2>&1; then \
		echo "✨ 格式化代码..."; \
		find Sources -name "*.swift" -exec swift-format -i {} \; ; \
		find Tests -name "*.swift" -exec swift-format -i {} \; ; \
		echo "✅ 格式化完成"; \
	else \
		echo "❌ 请先安装 swift-format"; \
		echo "   brew install swift-format"; \
	fi

# 代码检查
lint: ## 代码检查（需要 swiftlint）
	@if command -v swiftlint >/dev/null 2>&1; then \
		echo "🔍 代码检查..."; \
		swiftlint; \
		echo "✅ 检查完成"; \
	else \
		echo "❌ 请先安装 swiftlint"; \
		echo "   brew install swiftlint"; \
	fi

# 显示版本
version: ## 显示工具版本
	@echo "OTool iOS v1.0.0"

# 显示构建信息
info: ## 显示构建信息
	@echo "📊 项目信息:"
	@echo "  名称: OTool iOS"
	@echo "  版本: 1.0.0"
	@echo "  Swift: $$(swift --version | head -n1)"
	@echo "  平台: iOS 15+, macOS 12+"

# 完整构建和测试
all: clean build test ## 清理、构建、测试
	@echo "✅ 所有任务完成"
