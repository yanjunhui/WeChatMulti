//
//  LaunchAtLoginManager.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import Foundation
import ServiceManagement
import Combine

/// 开机自启管理器
/// 管理应用的开机自动启动设置
final class LaunchAtLoginManager: ObservableObject {

    // MARK: - 单例

    static let shared = LaunchAtLoginManager()

    // MARK: - 发布的属性

    /// 当前是否设置为开机自启
    @Published private(set) var isEnabled: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 初始化

    private init() {
        checkCurrentStatus()
    }

    // MARK: - 公共方法

    /// 设置开机自启
    /// - Parameter enabled: 是否启用
    func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            isEnabled = enabled
            errorMessage = nil

            // 同步到 UserDefaults (AppStorage)
            UserDefaults.standard.set(enabled, forKey: "launchAtLogin")
        } catch {
            errorMessage = "设置开机自启失败: \(error.localizedDescription)"
            print("设置开机自启失败: \(error)")
        }
    }

    /// 切换开机自启状态
    func toggle() {
        setLaunchAtLogin(enabled: !isEnabled)
    }

    /// 检查当前状态
    func checkCurrentStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled

        // 同步到 UserDefaults (AppStorage)
        UserDefaults.standard.set(isEnabled, forKey: "launchAtLogin")
    }
}
