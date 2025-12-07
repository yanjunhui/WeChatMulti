//
//  InstanceCardView.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import SwiftUI

/// 微信实例卡片视图
/// 以卡片形式展示单个微信实例，包含图标、名称、状态信息和操作按钮
struct InstanceCardView: View {

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
    @State private var showRenameSheet: Bool = false

    /// 新名称输入
    @State private var newName: String = ""

    /// 是否显示关闭按钮悬停
    @State private var isCloseHovered: Bool = false

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 卡片主体
            cardContent
        }
        .frame(width: AppTheme.Dimensions.cardWidth, height: AppTheme.Dimensions.cardHeight)
        .background(cardBackground)
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.Dimensions.cardCornerRadius))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Dimensions.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Dimensions.cardCornerRadius)
                .stroke(
                    instance.isCreating ? AppTheme.Colors.primary.opacity(0.3) :
                    (isHovered ? AppTheme.Colors.primary.opacity(0.5) : Color.secondary.opacity(0.2)),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(isHovered ? 0.18 : 0.1),
            radius: isHovered ? 16 : 8,
            x: 0,
            y: isHovered ? 8 : 4
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(AppTheme.Animations.spring, value: isHovered)
        .onHover { hovering in
            if !instance.isCreating {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            guard !instance.isCreating else { return }
            if instance.isRunning {
                onActivate?()
            } else {
                onLaunch?()
            }
        }
        .onTapGesture(count: 1) {
            guard !instance.isCreating else { return }
            if instance.isRunning {
                onActivate?()
            } else {
                onLaunch?()
            }
        }
        .contextMenu {
            if !instance.isCreating {
                contextMenuContent
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            renameSheet
        }
        .disabled(instance.isCreating)
    }

    // MARK: - 卡片内容

    private var cardContent: some View {
        VStack(spacing: AppTheme.Dimensions.smallSpacing) {
            Spacer()
                .frame(height: 8)

            // 微信图标（含操作按钮）
            instanceIcon

            // 实例名称
            Text(instance.displayName)
                .font(AppTheme.Fonts.subtitle)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            // 状态信息
            statusInfo

            Spacer()
        }
        .padding(.horizontal, AppTheme.Dimensions.smallPadding)
        .padding(.bottom, AppTheme.Dimensions.smallPadding)
    }

    // MARK: - 微信图标

    /// 操作按钮尺寸（与图标大小相同，完全覆盖背景）
    private var actionButtonSize: CGFloat {
        AppTheme.Dimensions.cardIconSize
    }

    private var instanceIcon: some View {
        ZStack {
            if instance.isCreating {
                // 创建中状态 - 显示进度指示器
                Circle()
                    .stroke(AppTheme.Colors.primary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: AppTheme.Dimensions.cardIconSize, height: AppTheme.Dimensions.cardIconSize)

                ProgressView()
                    .scaleEffect(0.9)
            } else {
                // 背景圆形
                Circle()
                    .fill(instance.isRunning ? AppTheme.Colors.primaryGradient : AppTheme.Colors.inactiveGradient)
                    .frame(width: AppTheme.Dimensions.cardIconSize, height: AppTheme.Dimensions.cardIconSize)

                // 微信图标（悬停时淡出）
                Image(systemName: "message.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
                    .opacity(isHovered ? 0 : 1)
                    .scaleEffect(isHovered ? 0.6 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)

                // 操作按钮（悬停时淡入并放大）
                actionButton
                    .opacity(isHovered ? 1 : 0)
                    .scaleEffect(isHovered ? 1.0 : 0.5)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)

                // 运行状态指示器
                if instance.isRunning {
                    Circle()
                        .fill(AppTheme.Colors.success)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: 20, y: 20)
                }
            }
        }
    }

    // MARK: - 状态信息

    private var statusInfo: some View {
        VStack(spacing: 4) {
            if instance.isCreating {
                // 创建中状态
                Text("创建中...")
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.primary)

                Text("请稍候")
                    .font(AppTheme.Fonts.tiny)
                    .foregroundColor(.secondary.opacity(0.7))
            } else if instance.isRunning {
                // 运行时长
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(instance.runningDuration)
                        .font(AppTheme.Fonts.tiny)
                }
                .foregroundColor(.secondary)

                // 内存占用
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 9))
                    Text(instance.formattedMemoryUsage)
                        .font(AppTheme.Fonts.tiny)
                }
                .foregroundColor(.secondary)
            } else {
                // 未运行状态
                Text("未启动")
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(.secondary)

                Text("点击启动")
                    .font(AppTheme.Fonts.tiny)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .frame(height: 36)
    }

    // MARK: - 操作按钮

    private var actionButton: some View {
        Group {
            if instance.isRunning {
                // 停止按钮（方形图标）
                Button(action: {
                    onTerminate?()
                }) {
                    ZStack {
                        Circle()
                            .fill(isCloseHovered ? AppTheme.Colors.danger : Color.white.opacity(0.9))
                            .frame(width: actionButtonSize, height: actionButtonSize)

                        Image(systemName: "stop.fill")
                            .font(.system(size: actionButtonSize * 0.4, weight: .semibold))
                            .foregroundColor(isCloseHovered ? .white : AppTheme.Colors.danger)
                    }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(AppTheme.Animations.fast) {
                        isCloseHovered = hovering
                    }
                }
                .help("终止此实例")
            } else {
                // 启动按钮（播放图标）
                Button(action: {
                    onLaunch?()
                }) {
                    ZStack {
                        Circle()
                            .fill(isCloseHovered ? AppTheme.Colors.primary : Color.white.opacity(0.9))
                            .frame(width: actionButtonSize, height: actionButtonSize)

                        Image(systemName: "play.fill")
                            .font(.system(size: actionButtonSize * 0.4, weight: .semibold))
                            .foregroundColor(isCloseHovered ? .white : AppTheme.Colors.primary)
                    }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(AppTheme.Animations.fast) {
                        isCloseHovered = hovering
                    }
                }
                .help("启动此实例")
            }
        }
        .animation(AppTheme.Animations.fast, value: isCloseHovered)
    }

    // MARK: - 卡片背景

    private var cardBackground: some View {
        Color.clear
//        Group {
//            if #available(macOS 26.0, *) {
//                RoundedRectangle(cornerRadius: AppTheme.Dimensions.cardCornerRadius)
//                    .fill(.regularMaterial)
//                    .glassEffect(.regular)
//            } else {
//                ZStack {
//                    GlassBackgroundView(material: .hudWindow)
//                    RoundedRectangle(cornerRadius: AppTheme.Dimensions.cardCornerRadius)
//                        .fill(AppTheme.Colors.cardBackground.opacity(0.8))
//                }
//            }
//        }
    }

    // MARK: - 右键菜单

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
                showRenameSheet = true
            }) {
                Label("修改名称", systemImage: "pencil")
            }

            if let pid = instance.processId {
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("\(pid)", forType: .string)
                }) {
                    Label("复制 PID (\(pid))", systemImage: "doc.on.doc")
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
                showRenameSheet = true
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

    // MARK: - 重命名弹窗

    private var renameSheet: some View {
        VStack(spacing: 20) {
            // 图标
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primaryGradient)
                    .frame(width: 48, height: 48)

                Image(systemName: "pencil")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text("修改显示名称")
                .font(AppTheme.Fonts.title)

            TextField("输入新名称", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)

            HStack(spacing: 12) {
                Button("取消") {
                    showRenameSheet = false
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)

                Button("恢复默认") {
                    onRename?("")
                    showRenameSheet = false
                }
                .buttonStyle(.bordered)

                Button("确定") {
                    onRename?(newName)
                    showRenameSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.primary)
                .disabled(newName.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 320)
    }
}

// MARK: - 新建实例卡片

/// 新建实例卡片
/// 显示为带有 + 号的特殊卡片，点击后创建新实例
struct AddInstanceCardView: View {

    /// 点击回调
    let onTap: () -> Void

    /// 是否悬停
    @State private var isHovered: Bool = false

    var body: some View {
        VStack(spacing: AppTheme.Dimensions.smallSpacing) {
            Spacer()

            // 加号图标
            ZStack {
                Circle()
                    .stroke(
                        isHovered ? AppTheme.Colors.primary : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
                    .frame(width: AppTheme.Dimensions.cardIconSize, height: AppTheme.Dimensions.cardIconSize)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isHovered ? AppTheme.Colors.primary : .secondary)
            }

            // 文字
            Text("新建微信")
                .font(AppTheme.Fonts.subtitle)
                .foregroundColor(isHovered ? AppTheme.Colors.primary : .secondary)

            Text("点击启动新实例")
                .font(AppTheme.Fonts.tiny)
                .foregroundColor(.secondary.opacity(0.7))

            Spacer()
        }
        .frame(width: AppTheme.Dimensions.cardWidth, height: AppTheme.Dimensions.cardHeight)
        .background(addCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Dimensions.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Dimensions.cardCornerRadius)
                .stroke(
                    isHovered ? AppTheme.Colors.primary.opacity(0.5) : Color.secondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: 1, dash: isHovered ? [] : [8, 4])
                )
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(AppTheme.Animations.spring, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
    }

    private var addCardBackground: some View {
        Group {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: AppTheme.Dimensions.cardCornerRadius)
                    .fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: AppTheme.Dimensions.cardCornerRadius)
                    .fill(AppTheme.Colors.cardBackground.opacity(0.5))
            }
        }
    }
}

// MARK: - 预览

#Preview("运行中的实例") {
    HStack(spacing: 20) {
        InstanceCardView(
            instance: WeChatInstance(
                processId: 12345,
                launchTime: Date().addingTimeInterval(-3600),
                bundleIdentifier: "com.tencent.xinWeChat",
                instanceNumber: 0
            )
        )

        InstanceCardView(
            instance: WeChatInstance(
                bundleIdentifier: "com.tencent.xinWeChat.copy1",
                copyPath: "/path/to/copy",
                instanceNumber: 1
            )
        )

        AddInstanceCardView {
            print("新建")
        }
    }
    .padding(40)
    .background(Color(NSColor.windowBackgroundColor))
}
