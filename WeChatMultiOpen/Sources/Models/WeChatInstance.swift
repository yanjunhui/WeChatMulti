//
//  WeChatInstance.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import Foundation

/// 微信实例模型
/// 用于表示微信实例（包括原版微信、运行中的副本、未运行的副本）
struct WeChatInstance: Identifiable, Equatable, Hashable {

    /// 唯一标识符，使用 Bundle Identifier 作为标识
    var id: String {
        return bundleIdentifier
    }

    /// 进程ID（未运行时为 nil）
    var processId: pid_t?

    /// 进程启动时间（未运行时为 nil）
    var launchTime: Date?

    /// Bundle Identifier（用于区分原版和副本）
    let bundleIdentifier: String

    /// 副本路径（原版微信为 nil）
    var copyPath: String?

    /// 实例序号（用于排序显示，原版为0，副本为1,2,3...）
    let instanceNumber: Int

    /// 进程是否正在运行
    var isRunning: Bool

    /// CPU使用率（百分比）
    var cpuUsage: Double

    /// 内存使用量（MB）
    var memoryUsage: Double

    /// 自定义显示名称（由用户设置，存储在 WeChatManager 中）
    var customName: String?

    /// 运行时长的格式化字符串
    var runningDuration: String {
        guard let launchTime = launchTime, isRunning else {
            return "-"
        }
        let interval = Date().timeIntervalSince(launchTime)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%d时%02d分%02d秒", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%d分%02d秒", minutes, seconds)
        } else {
            return String(format: "%d秒", seconds)
        }
    }

    /// 显示名称
    var displayName: String {
        // 如果有自定义名称，优先使用
        if let custom = customName, !custom.isEmpty {
            return custom
        }
        // 默认都显示"微信"
        return "微信"
    }

    /// 内存使用量的格式化字符串
    var formattedMemoryUsage: String {
        guard isRunning else { return "-" }
        if memoryUsage >= 1024 {
            return String(format: "%.1f GB", memoryUsage / 1024)
        } else {
            return String(format: "%.1f MB", memoryUsage)
        }
    }

    /// CPU使用率的格式化字符串
    var formattedCPUUsage: String {
        guard isRunning else { return "-" }
        return String(format: "%.1f%%", cpuUsage)
    }

    /// 是否是原版微信
    var isOriginal: Bool {
        return bundleIdentifier == "com.tencent.xinWeChat"
    }

    // MARK: - Initializer

    /// 创建运行中的实例
    init(processId: pid_t, launchTime: Date, bundleIdentifier: String, instanceNumber: Int) {
        self.processId = processId
        self.launchTime = launchTime
        self.bundleIdentifier = bundleIdentifier
        self.copyPath = nil
        self.instanceNumber = instanceNumber
        self.isRunning = true
        self.cpuUsage = 0.0
        self.memoryUsage = 0.0
    }

    /// 创建未运行的副本实例
    init(bundleIdentifier: String, copyPath: String, instanceNumber: Int) {
        self.processId = nil
        self.launchTime = nil
        self.bundleIdentifier = bundleIdentifier
        self.copyPath = copyPath
        self.instanceNumber = instanceNumber
        self.isRunning = false
        self.cpuUsage = 0.0
        self.memoryUsage = 0.0
    }

    // MARK: - Equatable

    static func == (lhs: WeChatInstance, rhs: WeChatInstance) -> Bool {
        return lhs.bundleIdentifier == rhs.bundleIdentifier
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
}

// MARK: - 实例状态枚举

enum WeChatInstanceStatus {
    case running      // 运行中
    case launching    // 启动中
    case terminated   // 已终止
    case notResponding // 无响应

    var displayText: String {
        switch self {
        case .running:
            return "运行中"
        case .launching:
            return "启动中"
        case .terminated:
            return "已终止"
        case .notResponding:
            return "无响应"
        }
    }

    var statusColor: String {
        switch self {
        case .running:
            return "green"
        case .launching:
            return "orange"
        case .terminated:
            return "gray"
        case .notResponding:
            return "red"
        }
    }
}
