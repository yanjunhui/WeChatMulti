//
//  ProcessMonitor.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import Foundation
import AppKit

/// 进程监控器
/// 负责监控系统中的微信进程，提供进程状态信息
final class ProcessMonitor {

    // MARK: - 单例

    static let shared = ProcessMonitor()

    // MARK: - 常量

    /// 微信应用的Bundle Identifier 前缀（用于匹配原版和副本）
    private let wechatBundleIdentifierPrefix = "com.tencent.xinWeChat"

    /// 微信应用的进程名
    private let wechatProcessName = "WeChat"

    // MARK: - 初始化

    private init() {}

    // MARK: - 公共方法

    /// 获取当前运行的所有微信进程ID列表（包括原版和所有副本）
    /// - Returns: 微信进程ID数组
    func getRunningWeChatProcessIds() -> [pid_t] {
        let runningApps = NSWorkspace.shared.runningApplications
        let wechatApps = runningApps.filter { app in
            // 匹配原版微信和所有副本（com.tencent.xinWeChat, com.tencent.xinWeChat.copy2 等）
            if let bundleId = app.bundleIdentifier {
                return bundleId.hasPrefix(wechatBundleIdentifierPrefix)
            }
            // 也匹配进程名
            return app.localizedName == wechatProcessName
        }
        return wechatApps.map { $0.processIdentifier }
    }

    /// 获取当前运行的微信应用数量
    /// - Returns: 运行中的微信实例数量
    func getRunningWeChatCount() -> Int {
        return getRunningWeChatProcessIds().count
    }

    /// 检查微信是否已安装
    /// - Returns: 如果微信已安装返回true
    func isWeChatInstalled() -> Bool {
        return getWeChatAppPath() != nil
    }

    /// 获取微信应用路径
    /// - Returns: 微信应用的完整路径，如果未安装返回nil
    func getWeChatAppPath() -> String? {
        // 常见安装路径
        let possiblePaths = [
            "/Applications/WeChat.app",
            "/Applications/微信.app",
            "\(NSHomeDirectory())/Applications/WeChat.app",
            "\(NSHomeDirectory())/Applications/微信.app"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // 使用mdfind查找
        if let path = findWeChatUsingSpotlight() {
            return path
        }

        return nil
    }

    /// 获取进程的启动时间
    /// - Parameter pid: 进程ID
    /// - Returns: 进程启动时间，如果无法获取返回nil
    func getProcessLaunchTime(pid: pid_t) -> Date? {
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size

        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size))

        if result == size {
            // pbi_start_tvsec 是进程启动的秒数（自1970年以来）
            let startTime = TimeInterval(info.pbi_start_tvsec)
            return Date(timeIntervalSince1970: startTime)
        }

        return nil
    }

    /// 获取进程的CPU使用率
    /// - Parameter pid: 进程ID
    /// - Returns: CPU使用率百分比
    func getProcessCPUUsage(pid: pid_t) -> Double {
        var taskInfo = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size

        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(size))

        if result == size {
            // 计算CPU使用率需要两次采样，这里返回一个近似值
            let totalTime = Double(taskInfo.pti_total_user + taskInfo.pti_total_system)
            // 这是累计时间，需要除以运行时间来获得平均CPU使用率
            if let launchTime = getProcessLaunchTime(pid: pid) {
                let runningTime = Date().timeIntervalSince(launchTime)
                if runningTime > 0 {
                    // 转换为百分比（纳秒转秒）
                    return (totalTime / 1_000_000_000.0 / runningTime) * 100.0
                }
            }
        }

        return 0.0
    }

    /// 获取进程的内存使用量
    /// - Parameter pid: 进程ID
    /// - Returns: 内存使用量（MB）
    func getProcessMemoryUsage(pid: pid_t) -> Double {
        var taskInfo = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size

        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(size))

        if result == size {
            // 返回常驻内存大小（MB）
            let memoryBytes = Double(taskInfo.pti_resident_size)
            return memoryBytes / (1024.0 * 1024.0)
        }

        return 0.0
    }

    /// 检查进程是否仍在运行
    /// - Parameter pid: 进程ID
    /// - Returns: 如果进程正在运行返回true
    func isProcessRunning(pid: pid_t) -> Bool {
        return kill(pid, 0) == 0
    }

    /// 终止指定进程
    /// - Parameter pid: 要终止的进程ID
    /// - Returns: 如果成功终止返回true
    @discardableResult
    func terminateProcess(pid: pid_t) -> Bool {
        // 先尝试优雅终止
        let result = kill(pid, SIGTERM)

        if result == 0 {
            // 给进程一些时间来优雅关闭
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
                // 如果进程仍在运行，强制终止
                if self?.isProcessRunning(pid: pid) == true {
                    kill(pid, SIGKILL)
                }
            }
            return true
        }

        return false
    }

    /// 获取NSRunningApplication对象
    /// - Parameter pid: 进程ID
    /// - Returns: NSRunningApplication对象，如果找不到返回nil
    func getRunningApplication(pid: pid_t) -> NSRunningApplication? {
        // 使用 NSWorkspace 查找真正运行中的应用
        // NSRunningApplication(processIdentifier:) 可能返回已终止的应用
        return NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }
    }

    // MARK: - 私有方法

    /// 使用Spotlight查找微信应用
    private func findWeChatUsingSpotlight() -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/mdfind"
        task.arguments = ["kMDItemCFBundleIdentifier == 'com.tencent.xinWeChat'"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let paths = output.components(separatedBy: "\n").filter { !$0.isEmpty }
                return paths.first
            }
        } catch {
            print("查找微信应用失败: \(error)")
        }

        return nil
    }
}

// MARK: - C函数声明

// 进程信息结构体
private struct proc_bsdinfo {
    var pbi_flags: UInt32 = 0
    var pbi_status: UInt32 = 0
    var pbi_xstatus: UInt32 = 0
    var pbi_pid: UInt32 = 0
    var pbi_ppid: UInt32 = 0
    var pbi_uid: uid_t = 0
    var pbi_gid: gid_t = 0
    var pbi_ruid: uid_t = 0
    var pbi_rgid: gid_t = 0
    var pbi_svuid: uid_t = 0
    var pbi_svgid: gid_t = 0
    var rfu_1: UInt32 = 0
    var pbi_comm: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    var pbi_name: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                                                              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    var pbi_nfiles: UInt32 = 0
    var pbi_pgid: UInt32 = 0
    var pbi_pjobc: UInt32 = 0
    var e_tdev: UInt32 = 0
    var e_tpgid: UInt32 = 0
    var pbi_nice: Int32 = 0
    var pbi_start_tvsec: UInt64 = 0
    var pbi_start_tvusec: UInt64 = 0
}

private struct proc_taskinfo {
    var pti_virtual_size: UInt64 = 0
    var pti_resident_size: UInt64 = 0
    var pti_total_user: UInt64 = 0
    var pti_total_system: UInt64 = 0
    var pti_threads_user: UInt64 = 0
    var pti_threads_system: UInt64 = 0
    var pti_policy: Int32 = 0
    var pti_faults: Int32 = 0
    var pti_pageins: Int32 = 0
    var pti_cow_faults: Int32 = 0
    var pti_messages_sent: Int32 = 0
    var pti_messages_received: Int32 = 0
    var pti_syscalls_mach: Int32 = 0
    var pti_syscalls_unix: Int32 = 0
    var pti_csw: Int32 = 0
    var pti_threadnum: Int32 = 0
    var pti_numrunning: Int32 = 0
    var pti_priority: Int32 = 0
}

private let PROC_PIDTBSDINFO: Int32 = 3
private let PROC_PIDTASKINFO: Int32 = 4

@_silgen_name("proc_pidinfo")
private func proc_pidinfo(_ pid: pid_t, _ flavor: Int32, _ arg: UInt64, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32
