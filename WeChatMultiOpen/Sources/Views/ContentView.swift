//
//  ContentView.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import SwiftUI

/// 主内容视图
/// 应用程序的主界面，以卡片网格形式显示微信实例
struct ContentView: View {

    // MARK: - 属性

    /// 视图模型
    @StateObject private var viewModel = MainViewModel()

    /// 更新管理器
    @StateObject private var updateManager = UpdateManager.shared

    /// 窗口控制
    @Environment(\.dismiss) private var dismiss

    /// 是否显示更新弹窗
    @State private var showUpdateSheet: Bool = false

    /// 是否使用卡片视图模式（false 为列表模式）
    @State private var isCardViewMode: Bool = true

    /// 网格列定义 - 自适应列数
    private let gridColumns = [
        GridItem(.adaptive(minimum: AppTheme.Dimensions.gridMinColumnWidth), spacing: AppTheme.Dimensions.spacing)
    ]

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 头部区域
            headerView

            // 主内容区域
            if viewModel.isWeChatInstalled {
                mainContentView
            } else {
                wechatNotInstalledView
            }

            // 底部状态栏
            footerStatusBar
        }
        .frame(
            minWidth: AppTheme.Dimensions.windowMinWidth,
            minHeight: AppTheme.Dimensions.windowMinHeight
        )
        .background(windowBackground)
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "发生未知错误")
        }
        .alert("确认终止", isPresented: $viewModel.showTerminateConfirmation) {
            Button("取消", role: .cancel) {
                viewModel.cancelOperation()
            }
            Button("终止", role: .destructive) {
                viewModel.confirmTerminateInstance()
            }
        } message: {
            if let instance = viewModel.selectedInstance {
                Text("确定要终止「\(instance.displayName)」吗？\n未保存的数据可能会丢失。")
            }
        }
        .alert("确认终止所有实例", isPresented: $viewModel.showTerminateAllConfirmation) {
            Button("取消", role: .cancel) {
                viewModel.cancelOperation()
            }
            Button("全部终止", role: .destructive) {
                viewModel.confirmTerminateAllInstances()
            }
        } message: {
            Text("确定要终止所有 \(viewModel.runningInstanceCount) 个微信实例吗？\n未保存的数据可能会丢失。")
        }
        .sheet(isPresented: $viewModel.showDeleteConfirmation) {
            DeleteConfirmationSheet(
                instanceName: viewModel.selectedInstance?.displayName ?? "微信",
                onCancel: {
                    viewModel.cancelOperation()
                },
                onConfirm: {
                    viewModel.confirmDeleteInstance()
                }
            )
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showUpdateSheet) {
            if let update = updateManager.availableUpdate {
                UpdateAvailableSheet(
                    updateInfo: update,
                    onDismiss: {
                        showUpdateSheet = false
                    },
                    onDownload: {
                        updateManager.openDownloadPage()
                        showUpdateSheet = false
                    },
                    onIgnore: {
                        updateManager.ignoreCurrentUpdate()
                        showUpdateSheet = false
                    }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showUpdateSheet)) { _ in
            if updateManager.availableUpdate != nil {
                showUpdateSheet = true
            }
        }
    }

    // MARK: - 窗口背景

    private var windowBackground: some View {
        Group {
            if #available(macOS 26.0, *) {
                Rectangle()
                    .fill(.regularMaterial)
            } else {
                GlassBackgroundView(material: .sidebar, blendingMode: .behindWindow)
            }
        }
    }

    // MARK: - 头部视图

    private var headerView: some View {
        HStack(spacing: AppTheme.Dimensions.spacing) {
            // 应用图标和标题
            HStack(spacing: 12) {
                // 应用图标
                appIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text("微信多开")
                        .font(AppTheme.Fonts.title)
                        .foregroundColor(.primary)

                    Text(viewModel.statusText)
                        .font(AppTheme.Fonts.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 工具按钮组
            HStack(spacing: 4) {
                // 切换视图模式按钮
                Button(action: {
                    withAnimation(AppTheme.Animations.standard) {
                        isCardViewMode.toggle()
                    }
                }) {
                    Image(systemName: isCardViewMode ? "list.bullet" : "square.grid.2x2")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(IconButtonStyle())
                .help(isCardViewMode ? "切换到列表视图" : "切换到卡片视图")

                // 设置按钮
                Button(action: {
                    viewModel.showSettings = true
                }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .medium))

                        // 有更新时显示小红点
                        if updateManager.hasUpdate {
                            Circle()
                                .fill(AppTheme.Colors.danger)
                                .frame(width: 8, height: 8)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(IconButtonStyle())
                .help(updateManager.hasUpdate ? "设置 (有新版本可用)" : "设置")
            }
        }
        .padding(.horizontal, AppTheme.Dimensions.largePadding)
        .padding(.vertical, AppTheme.Dimensions.padding)
        .background(headerBackground)
    }

    /// 应用图标
    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.Colors.primaryGradient)
                .frame(width: 42, height: 42)

            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
        }
        .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    /// 头部背景
    private var headerBackground: some View {
        Group {
            if #available(macOS 26.0, *) {
                Rectangle()
                    .fill(.ultraThinMaterial)
            } else {
                Rectangle()
                    .fill(AppTheme.Colors.cardBackground.opacity(0.8))
            }
        }
    }

    // MARK: - 主内容区域

    private var mainContentView: some View {
        Group {
            if isCardViewMode {
                cardGridView
            } else {
                listView
            }
        }
    }

    // MARK: - 卡片网格视图

    private var cardGridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: AppTheme.Dimensions.spacing) {
                // 实例卡片
                ForEach(viewModel.instances) { instance in
                    InstanceCardView(
                        instance: instance,
                        onActivate: {
                            viewModel.activateInstance(instance)
                        },
                        onTerminate: {
                            viewModel.showTerminateConfirmationDialog(for: instance)
                        },
                        onLaunch: {
                            viewModel.launchInstance(instance)
                        },
                        onCopyPID: {
                            viewModel.copyProcessId(instance)
                        },
                        onRename: { newName in
                            viewModel.renameInstance(instance, to: newName)
                        },
                        onDelete: {
                            viewModel.showDeleteConfirmationDialog(for: instance)
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }

                // 新建实例卡片
                AddInstanceCardView(
                    isLoading: viewModel.isLaunching,
                    onTap: {
                        viewModel.launchNewInstance()
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
            .padding(AppTheme.Dimensions.largePadding)
            .animation(AppTheme.Animations.standard, value: viewModel.instances.count)
        }
    }

    // MARK: - 列表视图

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 实例列表
                ForEach(viewModel.instances) { instance in
                    InstanceRowView(
                        instance: instance,
                        onActivate: {
                            viewModel.activateInstance(instance)
                        },
                        onTerminate: {
                            viewModel.showTerminateConfirmationDialog(for: instance)
                        },
                        onLaunch: {
                            viewModel.launchInstance(instance)
                        },
                        onCopyPID: {
                            viewModel.copyProcessId(instance)
                        },
                        onRename: { newName in
                            viewModel.renameInstance(instance, to: newName)
                        },
                        onDelete: {
                            viewModel.showDeleteConfirmationDialog(for: instance)
                        }
                    )
                    .transition(.opacity)
                }

                // 新建实例行
                AddInstanceRowView(
                    isLoading: viewModel.isLaunching,
                    onTap: {
                        viewModel.launchNewInstance()
                    }
                )
                .transition(.opacity)
            }
            .padding(AppTheme.Dimensions.padding)
            .animation(AppTheme.Animations.standard, value: viewModel.instances.count)
        }
    }

    // MARK: - 微信未安装视图

    private var wechatNotInstalledView: some View {
        VStack(spacing: AppTheme.Dimensions.largePadding) {
            Spacer()

            // 警告图标
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.warning.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(AppTheme.Colors.warning)
            }

            VStack(spacing: 8) {
                Text("未检测到微信应用")
                    .font(AppTheme.Fonts.title)
                    .foregroundColor(.primary)

                Text("请先安装微信 Mac 版后再使用本工具")
                    .font(AppTheme.Fonts.body)
                    .foregroundColor(.secondary)
            }

            Button(action: {
                viewModel.openWeChatDownloadPage()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("前往下载微信")
                }
            }
            .buttonStyle(.primary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 底部状态栏

    private var footerStatusBar: some View {
        HStack {
            // 运行统计
            HStack(spacing: 16) {
                // 运行中数量
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppTheme.Colors.success)
                        .frame(width: 8, height: 8)
                    Text("\(viewModel.runningInstanceCount) 个运行中")
                        .font(AppTheme.Fonts.caption)
                        .foregroundColor(.secondary)
                }

                // 副本数量
                if viewModel.copyCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                        Text("\(viewModel.copyCount) 个副本")
                            .font(AppTheme.Fonts.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 全部终止按钮
            if viewModel.hasRunningInstances {
                Button(action: {
                    viewModel.showTerminateAllConfirmationDialog()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 11))
                        Text("全部终止")
                            .font(AppTheme.Fonts.caption)
                    }
                    .foregroundColor(AppTheme.Colors.danger)
                }
                .buttonStyle(.plain)
                .opacity(0.8)
                .help("终止所有运行中的微信实例")
            }
        }
        .padding(.horizontal, AppTheme.Dimensions.largePadding)
        .padding(.vertical, AppTheme.Dimensions.smallPadding + 4)
        .background(footerBackground)
    }

    /// 底部背景
    private var footerBackground: some View {
        Group {
            if #available(macOS 26.0, *) {
                Rectangle()
                    .fill(.ultraThinMaterial)
            } else {
                Rectangle()
                    .fill(AppTheme.Colors.cardBackground.opacity(0.6))
            }
        }
    }
}

// MARK: - 删除确认弹窗

/// 删除副本确认弹窗
struct DeleteConfirmationSheet: View {
    let instanceName: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var isConfirmed: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            // 警告图标
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.warning.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppTheme.Colors.warning)
            }

            // 标题和说明
            VStack(spacing: 8) {
                Text("确认删除副本")
                    .font(AppTheme.Fonts.title)

                Text("确定要删除「\(instanceName)」吗？")
                    .font(AppTheme.Fonts.body)
                    .foregroundColor(.primary)
            }

            // 警告信息
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.danger)
                    Text("删除后所有数据将被永久清除")
                }
                Text("此操作不可恢复")
            }
            .font(AppTheme.Fonts.caption)
            .foregroundColor(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.danger.opacity(0.08))
            )

            // 确认勾选
            HStack(spacing: 8) {
                Toggle("", isOn: $isConfirmed)
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                Text("我已了解该微信所有聊天记录将被删除")
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(.primary)
            }

            // 按钮
            HStack(spacing: 12) {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)

                Button("删除") {
                    onConfirm()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.danger)
                .disabled(!isConfirmed)
            }
        }
        .padding(32)
        .frame(width: 380)
    }
}

// MARK: - 预览

#Preview {
    ContentView()
}

#Preview("DeleteConfirmationSheet") {
    DeleteConfirmationSheet(
        instanceName: "微信副本 1",
        onCancel: {},
        onConfirm: {}
    )
}
