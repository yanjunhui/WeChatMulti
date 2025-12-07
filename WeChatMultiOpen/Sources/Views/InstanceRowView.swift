//
//  InstanceRowView.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import SwiftUI

/// 微信实例行视图
/// 显示单个微信实例的详细信息和操作按钮
struct InstanceRowView: View {

    // MARK: - 属性

    /// 微信实例
    let instance: WeChatInstance

    /// 激活实例回调
    var onActivate: (() -> Void)?

    /// 终止实例回调
    var onTerminate: (() -> Void)?

    /// 启动实例回调
    var onLaunch: (() -> Void)?

    /// 复制PID回调
    var onCopyPID: (() -> Void)?

    /// 重命名回调
    var onRename: ((String) -> Void)?

    /// 删除副本回调
    var onDelete: (() -> Void)?

    /// 是否悬停
    @State private var isHovered: Bool = false

    /// 是否显示重命名对话框
    @State private var showRenameAlert: Bool = false

    /// 新名称输入
    @State private var newName: String = ""

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 12) {
            // 微信图标和实例名称
            HStack(spacing: 10) {
                // 微信图标
                wechatIcon

                // 实例信息
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(instance.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)

                        // 运行状态标签
                        if instance.isCreating {
                            Text("创建中")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppTheme.Colors.primary))
                        } else if instance.isRunning {
                            Text("运行中")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green))
                        } else {
                            Text("未启动")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.gray))
                        }
                    }

                    if instance.isCreating {
                        Text("请稍候...")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.primary)
                    } else if instance.isRunning, let pid = instance.processId {
                        Text("PID: \(pid)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        Text("双击启动")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // 状态信息（仅运行中显示）
            if instance.isRunning {
                VStack(alignment: .trailing, spacing: 2) {
                    // 运行时长
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(instance.runningDuration)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    // 内存和CPU
                    HStack(spacing: 8) {
                        // 内存使用
                        HStack(spacing: 2) {
                            Image(systemName: "memorychip")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)
                            Text(instance.formattedMemoryUsage)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        // CPU使用
                        HStack(spacing: 2) {
                            Image(systemName: "cpu")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                            Text(instance.formattedCPUUsage)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // 操作按钮
            HStack(spacing: 8) {
                if instance.isCreating {
                    // 创建中显示进度指示器
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                } else if instance.isRunning {
                    // 激活按钮
                    Button(action: {
                        onActivate?()
                    }) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("激活窗口")

                    // 终止按钮
                    Button(action: {
                        onTerminate?()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("终止此实例")
                } else {
                    // 启动按钮
                    Button(action: {
                        onLaunch?()
                    }) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                    .help("启动此实例")
                }
            }
            .opacity(instance.isCreating ? 1 : (isHovered ? 1 : 0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            if !instance.isCreating {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
        .onTapGesture(count: 2) {
            guard !instance.isCreating else { return }
            // 双击：运行中的激活窗口，未运行的启动
            if instance.isRunning {
                onActivate?()
            } else {
                onLaunch?()
            }
        }
        .onTapGesture(count: 1) {
            guard !instance.isCreating else { return }
            // 单击：运行中的激活窗口
            if instance.isRunning {
                onActivate?()
            }
        }
        .contextMenu {
            if !instance.isCreating {
                contextMenuContent
            }
        }
        .disabled(instance.isCreating)
        .sheet(isPresented: $showRenameAlert) {
            renameSheet
        }
    }

    /// 重命名弹窗
    private var renameSheet: some View {
        VStack(spacing: 16) {
            Text("修改显示名称")
                .font(.headline)

            TextField("输入新名称", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            HStack(spacing: 12) {
                Button("取消") {
                    showRenameAlert = false
                }
                .keyboardShortcut(.cancelAction)

                Button("恢复默认") {
                    onRename?("")
                    showRenameAlert = false
                }

                Button("确定") {
                    onRename?(newName)
                    showRenameAlert = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 280)
    }

    // MARK: - 子视图

    /// 微信图标
    private var wechatIcon: some View {
        ZStack {
            if instance.isCreating {
                // 创建中状态 - 显示进度指示器
                Circle()
                    .stroke(AppTheme.Colors.primary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .frame(width: 36, height: 36)

                ProgressView()
                    .scaleEffect(0.7)
            } else {
                // 背景圆形
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: instance.isRunning
                                ? [Color.green.opacity(0.8), Color.green]
                                : [Color.gray.opacity(0.5), Color.gray.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                // 微信图标（使用系统图标模拟）
                Image(systemName: "message.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    /// 右键菜单内容
    @ViewBuilder
    private var contextMenuContent: some View {
        if instance.isRunning {
            Button(action: {
                onActivate?()
            }) {
                Label("激活窗口", systemImage: "macwindow")
            }

            Button(action: {
                newName = instance.customName ?? ""
                showRenameAlert = true
            }) {
                Label("修改名称", systemImage: "pencil")
            }

            if let pid = instance.processId {
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("\(pid)", forType: .string)
                }) {
                    Label("复制 PID", systemImage: "doc.on.doc")
                }
            }

            Divider()

            Button(role: .destructive, action: {
                onTerminate?()
            }) {
                Label("终止实例", systemImage: "xmark.circle")
            }
        } else {
            Button(action: {
                onLaunch?()
            }) {
                Label("启动", systemImage: "play.circle")
            }

            Button(action: {
                newName = instance.customName ?? ""
                showRenameAlert = true
            }) {
                Label("修改名称", systemImage: "pencil")
            }

            if !instance.isOriginal {
                Divider()

                Button(role: .destructive, action: {
                    onDelete?()
                }) {
                    Label("删除副本", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - 新建实例行

/// 新建实例行视图
struct AddInstanceRowView: View {

    /// 点击回调
    let onTap: () -> Void

    /// 是否悬停
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // 加号图标
            ZStack {
                Circle()
                    .stroke(
                        isHovered ? AppTheme.Colors.primary : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isHovered ? AppTheme.Colors.primary : .secondary)
            }

            // 文字
            VStack(alignment: .leading, spacing: 2) {
                Text("新建微信")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isHovered ? AppTheme.Colors.primary : .secondary)

                Text("点击启动新实例")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? AppTheme.Colors.primary.opacity(0.08) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 8) {
        // 运行中的实例
        InstanceRowView(
            instance: WeChatInstance(
                processId: 12345,
                launchTime: Date().addingTimeInterval(-3600),
                bundleIdentifier: "com.tencent.xinWeChat",
                instanceNumber: 0
            ),
            onActivate: { print("激活") },
            onTerminate: { print("终止") },
            onLaunch: { print("启动") },
            onCopyPID: { print("复制PID") },
            onRename: { name in print("重命名: \(name)") },
            onDelete: { print("删除") }
        )

        // 未运行的副本
        InstanceRowView(
            instance: WeChatInstance(
                bundleIdentifier: "com.tencent.xinWeChat.copy1",
                copyPath: "/path/to/copy",
                instanceNumber: 1
            ),
            onActivate: { print("激活") },
            onTerminate: { print("终止") },
            onLaunch: { print("启动") },
            onCopyPID: { print("复制PID") },
            onRename: { name in print("重命名: \(name)") },
            onDelete: { print("删除") }
        )

        // 新建实例行
        AddInstanceRowView {
            print("新建")
        }
    }
    .padding()
    .frame(width: 420)
}
