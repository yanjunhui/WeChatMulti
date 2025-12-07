//
//  WeChatMultiOpenApp.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import SwiftUI

/// 微信多开应用程序入口
/// 这是一个 macOS 应用程序，用于同时运行多个微信实例
@main
struct WeChatMultiOpenApp: App {

    // MARK: - 属性

    /// 应用程序代理
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - 视图

    var body: some Scene {
        // 使用空的 WindowGroup，实际窗口由 AppDelegate 管理
        Settings {
            SettingsView()
        }
        .commands {
            // 替换默认的关于菜单
            CommandGroup(replacing: .appInfo) {
                Button("关于微信多开") {
                    openAboutWindow()
                }
            }
        }
    }

    /// 显示自定义关于窗口
    private func openAboutWindow() {
        let aboutView = AboutView()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "关于微信多开"
        window.center()
        window.contentView = NSHostingView(rootView: aboutView)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        // 保持窗口引用
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - 关于视图

/// 关于窗口视图
struct AboutView: View {

    var body: some View {
        VStack(spacing: 20) {
            // 应用图标
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green.opacity(0.7), Color.green]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.white)
            }

            // 应用名称
            Text("微信多开")
                .font(.system(size: 24, weight: .bold))

            // 版本号
            Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            // 开发者
            Text("Developed by Yanjunhui")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // 免责声明
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("免责声明")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("本应用只是为了方便启动多个微信，仅仅是对微信应用做了一个完整复制，没有对微信程序本身做任何修改，而且多个克隆体之间完全数据隔离，理论上没有任何安全风险。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("但是最终解释权归腾讯所有，个人不承担任何账号安全相关责任，如有侵权，强大的腾讯法务请速联系 i@yanjunhui.com，我将速删!")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .lineSpacing(3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer()

            // 版权信息
            Text("Copyright © 2025 Yanjunhui. All rights reserved.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 24)
        .frame(width: 400, height: 460)
    }
}
