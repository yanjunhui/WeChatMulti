//
//  AppTheme.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import SwiftUI

// MARK: - 应用主题配置

/// 应用主题
/// 定义全局颜色、尺寸、动画等设计常量
enum AppTheme {

    // MARK: - 主题色

    enum Colors {
        /// 主色调 - 微信绿
        static let primary = Color(red: 0.07, green: 0.73, blue: 0.37)

        /// 主色调浅色
        static let primaryLight = Color(red: 0.2, green: 0.8, blue: 0.5)

        /// 主色调深色
        static let primaryDark = Color(red: 0.05, green: 0.55, blue: 0.28)

        /// 次要色调
        static let secondary = Color.secondary

        /// 成功色
        static let success = Color(red: 0.2, green: 0.78, blue: 0.35)

        /// 警告色
        static let warning = Color(red: 1.0, green: 0.62, blue: 0.04)

        /// 危险色
        static let danger = Color(red: 0.95, green: 0.26, blue: 0.21)

        /// 信息色
        static let info = Color(red: 0.2, green: 0.6, blue: 1.0)

        /// 卡片背景色
        static var cardBackground: Color {
            Color(NSColor.controlBackgroundColor)
        }

        /// 窗口背景色
        static var windowBackground: Color {
            Color(NSColor.windowBackgroundColor)
        }

        /// 悬停背景色
        static var hoverBackground: Color {
            Color.primary.opacity(0.06)
        }

        /// 选中背景色
        static var selectedBackground: Color {
            primary.opacity(0.12)
        }

        /// 分割线颜色
        static var separator: Color {
            Color.primary.opacity(0.1)
        }

        /// 主色渐变
        static var primaryGradient: LinearGradient {
            LinearGradient(
                colors: [primaryLight, primary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// 灰色渐变（未激活状态）
        static var inactiveGradient: LinearGradient {
            LinearGradient(
                colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - 尺寸

    enum Dimensions {
        /// 窗口最小宽度
        static let windowMinWidth: CGFloat = 480

        /// 窗口最小高度
        static let windowMinHeight: CGFloat = 640

        /// 卡片尺寸
        static let cardWidth: CGFloat = 140
        static let cardHeight: CGFloat = 180

        /// 卡片图标尺寸
        static let cardIconSize: CGFloat = 56

        /// 卡片圆角
        static let cardCornerRadius: CGFloat = 16

        /// 小圆角
        static let smallCornerRadius: CGFloat = 8

        /// 中等圆角
        static let mediumCornerRadius: CGFloat = 12

        /// 大圆角
        static let largeCornerRadius: CGFloat = 20

        /// 标准间距
        static let spacing: CGFloat = 16

        /// 小间距
        static let smallSpacing: CGFloat = 8

        /// 大间距
        static let largeSpacing: CGFloat = 24

        /// 标准内边距
        static let padding: CGFloat = 16

        /// 小内边距
        static let smallPadding: CGFloat = 8

        /// 大内边距
        static let largePadding: CGFloat = 24

        /// 网格最小列宽
        static let gridMinColumnWidth: CGFloat = 150
    }

    // MARK: - 字体

    enum Fonts {
        /// 大标题
        static let largeTitle = Font.system(size: 20, weight: .bold)

        /// 标题
        static let title = Font.system(size: 16, weight: .semibold)

        /// 副标题
        static let subtitle = Font.system(size: 14, weight: .medium)

        /// 正文
        static let body = Font.system(size: 13, weight: .regular)

        /// 小字
        static let caption = Font.system(size: 11, weight: .regular)

        /// 极小字
        static let tiny = Font.system(size: 10, weight: .regular)

        /// 标签字体
        static let tag = Font.system(size: 9, weight: .medium)
    }

    // MARK: - 动画

    enum Animations {
        /// 快速动画
        static let fast = Animation.easeInOut(duration: 0.15)

        /// 标准动画
        static let standard = Animation.easeInOut(duration: 0.25)

        /// 慢速动画
        static let slow = Animation.easeInOut(duration: 0.4)

        /// 弹性动画
        static let spring = Animation.spring(response: 0.35, dampingFraction: 0.7)

        /// 轻微弹性
        static let gentleSpring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    }

    // MARK: - 阴影

    enum Shadows {
        /// 卡片阴影
        static func card(isHovered: Bool = false) -> some View {
            RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                .shadow(
                    color: Color.black.opacity(isHovered ? 0.15 : 0.08),
                    radius: isHovered ? 12 : 6,
                    x: 0,
                    y: isHovered ? 6 : 3
                )
        }

        /// 小阴影
        static let small = (color: Color.black.opacity(0.08), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))

        /// 中等阴影
        static let medium = (color: Color.black.opacity(0.12), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))

        /// 大阴影
        static let large = (color: Color.black.opacity(0.16), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
    }
}

// MARK: - 视图修饰器

extension View {
    /// 应用卡片样式
    func cardStyle(isHovered: Bool = false, isSelected: Bool = false) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Dimensions.cardCornerRadius)
                    .fill(AppTheme.Colors.cardBackground)
                    .shadow(
                        color: Color.black.opacity(isHovered ? 0.15 : 0.08),
                        radius: isHovered ? 12 : 6,
                        x: 0,
                        y: isHovered ? 6 : 3
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Dimensions.cardCornerRadius)
                    .stroke(
                        isSelected ? AppTheme.Colors.primary : Color.clear,
                        lineWidth: 2
                    )
            )
    }

    /// 应用玻璃效果背景
    func glassBackground() -> some View {
        self.background(GlassBackgroundView())
    }

    /// 悬停效果
    func hoverEffect(_ isHovered: Binding<Bool>) -> some View {
        self
            .scaleEffect(isHovered.wrappedValue ? 1.02 : 1.0)
            .animation(AppTheme.Animations.fast, value: isHovered.wrappedValue)
            .onHover { hovering in
                isHovered.wrappedValue = hovering
            }
    }
}

// MARK: - 玻璃背景视图

/// 玻璃背景效果
/// 在 macOS 26+ 使用液态玻璃，旧版本使用 NSVisualEffectView
struct GlassBackgroundView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - 液态玻璃效果修饰器

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.Dimensions.cardCornerRadius

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
                .background(
                    GlassBackgroundView(material: .hudWindow)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                )
        }
    }
}

extension View {
    /// 应用液态玻璃效果（macOS 26+）或毛玻璃效果（旧版本）
    func liquidGlass(cornerRadius: CGFloat = AppTheme.Dimensions.cardCornerRadius) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - 状态指示器样式

/// 运行状态指示点
struct StatusIndicator: View {
    let isRunning: Bool
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(isRunning ? AppTheme.Colors.success : Color.gray.opacity(0.5))
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: isRunning ? AppTheme.Colors.success.opacity(0.5) : .clear, radius: 3)
    }
}

// MARK: - 按钮样式

/// 主要按钮样式
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Fonts.subtitle)
            .foregroundColor(.white)
            .padding(.horizontal, AppTheme.Dimensions.padding)
            .padding(.vertical, AppTheme.Dimensions.smallPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Dimensions.smallCornerRadius)
                    .fill(AppTheme.Colors.primaryGradient)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(AppTheme.Animations.fast, value: configuration.isPressed)
    }
}

/// 次要按钮样式
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Fonts.subtitle)
            .foregroundColor(AppTheme.Colors.primary)
            .padding(.horizontal, AppTheme.Dimensions.padding)
            .padding(.vertical, AppTheme.Dimensions.smallPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Dimensions.smallCornerRadius)
                    .stroke(AppTheme.Colors.primary, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.Dimensions.smallCornerRadius)
                            .fill(AppTheme.Colors.primary.opacity(configuration.isPressed ? 0.1 : 0))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(AppTheme.Animations.fast, value: configuration.isPressed)
    }
}

/// 图标按钮样式
struct IconButtonStyle: ButtonStyle {
    var color: Color = AppTheme.Colors.secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color)
            .padding(6)
            .background(
                Circle()
                    .fill(color.opacity(configuration.isPressed ? 0.15 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(AppTheme.Animations.fast, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
