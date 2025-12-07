//
//  ContentView.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import SwiftUI

/// 主内容视图
/// 应用程序的主界面，显示微信实例列表和操作按钮
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

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 头部区域
            headerView

            Divider()

            // 主内容区域
            if viewModel.isWeChatInstalled {
                if viewModel.hasInstances {
                    instanceListView
                } else {
                    emptyStateView
                }
            } else {
                wechatNotInstalledView
            }

            Divider()

            // 底部操作区域
            footerView
        }
        .frame(minWidth: 420, minHeight: 360)
        .background(Color(NSColor.windowBackgroundColor))
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
                Text("确定要终止 \(instance.displayName) 吗？未保存的数据可能会丢失。")
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
            Text("确定要终止所有 \(viewModel.runningInstanceCount) 个微信实例吗？未保存的数据可能会丢失。")
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
            // 收到通知后显示更新弹窗
            if updateManager.availableUpdate != nil {
                showUpdateSheet = true
            }
        }
    }

    // MARK: - 子视图

    /// 头部视图
    private var headerView: some View {
        HStack {
            // 应用图标和标题
            HStack(spacing: 10) {
                // 应用图标
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.7), Color.green]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("微信多开")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(viewModel.statusText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 刷新按钮
            Button(action: {
                viewModel.refreshInstances()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("刷新实例列表")

            // 设置按钮
            Button(action: {
                viewModel.showSettings = true
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("设置")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    /// 实例列表视图
    private var instanceListView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
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
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }

    /// 空状态视图（微信已安装但没有运行的实例）
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "message.badge.circle")
                .font(.system(size: 48))
                .foregroundColor(.green.opacity(0.6))

            Text("没有运行中的微信")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)

            Text("点击下方按钮启动微信")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 微信未安装视图
    private var wechatNotInstalledView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("未检测到微信应用")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)

            Text("请先安装微信 Mac 版")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Button(action: {
                viewModel.openWeChatDownloadPage()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle")
                    Text("前往下载")
                }
                .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 底部视图
    private var footerView: some View {
        HStack {
            // 启动新实例按钮
            Button(action: {
                viewModel.launchNewInstance()
            }) {
                HStack(spacing: 6) {
                    if viewModel.isLaunching {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                        Text("正在准备...")
                    } else {
                        Image(systemName: "plus.circle.fill")
                        Text("启动新微信")
                    }
                }
                .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(!viewModel.isWeChatInstalled || viewModel.isLaunching)
            .help("首次启动新实例需要创建微信副本，可能需要几秒钟")

            Spacer()

            // 终止所有按钮
            if viewModel.hasRunningInstances {
                Button(action: {
                    viewModel.showTerminateAllConfirmationDialog()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                        Text("全部终止")
                    }
                    .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
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
        VStack(spacing: 20) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            // 标题
            Text("确认删除副本")
                .font(.system(size: 18, weight: .semibold))

            // 说明
            Text("确定要删除「\(instanceName)」吗？")
                .font(.system(size: 14))
                .foregroundColor(.primary)

            Text("删除后，该副本的所有数据将被永久清除，此操作不可恢复。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // 确认勾选
            HStack(spacing: 8) {
                Toggle("", isOn: $isConfirmed)
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                Text("该微信所有的聊天记录将会被删除，我已知悉")
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            }
            .padding(.top, 8)

            // 按钮
            HStack(spacing: 16) {
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
                .tint(.red)
                .disabled(!isConfirmed)
            }
            .padding(.top, 8)
        }
        .padding(30)
        .frame(width: 400)
    }
}

// MARK: - 预览

#Preview {
    ContentView()
}

#Preview("DeleteConfirmationSheet") {
    DeleteConfirmationSheet(
        instanceName: "微信",
        onCancel: {},
        onConfirm: {}
    )
}
