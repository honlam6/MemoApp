import Foundation
import WatchConnectivity

class WatchSyncManager: NSObject {

    enum SyncSendResult {
        case queued(String)
        case failed(String)

        var message: String {
            switch self {
            case .queued(let message), .failed(let message):
                return message
            }
        }

        var isSuccess: Bool {
            if case .queued = self {
                return true
            }
            return false
        }
    }

    static let shared = WatchSyncManager()

    private var session: WCSession?
    var onNotesReceived: (([Note]) -> Void)?
    var notesProvider: (() -> [Note])?
    private var pendingNotes: [Note]?
    private var isActivated = false
    private var lastSentPayloadHash: Int?
    private var lastReceivedPayloadHash: Int?
    private var lastSyncRequestAt: Date?

    #if os(iOS)
    private static let deviceTag = "iPhone"
    #else
    private static let deviceTag = "Watch"
    #endif

    private override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        guard WCSession.isSupported() else {
            log("WCSession 不支持此设备")
            return
        }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        log("WCSession activate() 已调用")
    }

    private func log(_ message: String) {
        let state: String
        if let s = session {
            switch s.activationState {
            case .notActivated: state = "notActivated"
            case .inactive: state = "inactive"
            case .activated: state = "activated"
            @unknown default: state = "unknown"
            }
        } else {
            state = "nil"
        }
        let reachable = session?.isReachable ?? false
        print("[Sync][\(WatchSyncManager.deviceTag)] \(message) | session=\(state), reachable=\(reachable)")
    }

    @discardableResult
    func sendNotes(_ notes: [Note], force: Bool = false) -> SyncSendResult {
        guard let session = session else {
            log("sendNotes: session 为 nil")
            return .failed("当前设备不支持 Watch 同步")
        }

        let payloadHash = notesPayloadHash(notes)
        if !force, lastSentPayloadHash == payloadHash {
            log("sendNotes: 内容未变化，跳过重复发送")
            return .queued("内容无变化，已跳过重复同步")
        }

        if session.activationState != .activated {
            log("sendNotes: session 未激活，暂存待发送")
            pendingNotes = notes
            return .queued("同步已排队，等待连接建立")
        }

        do {
            let data = try JSONEncoder().encode(notes)
            log("sendNotes: 准备发送 \(notes.count) 条笔记, \(data.count) bytes")

            let dict: [String: Any] = [
                "type": "notes_sync",
                "data": data,
                "timestamp": Date().timeIntervalSince1970
            ]

            #if os(iOS)
            guard session.isPaired else {
                log("sendNotes: Apple Watch 未配对")
                return .failed("Apple Watch 还没和 iPhone 配对")
            }

            guard session.isWatchAppInstalled else {
                log("sendNotes: Watch App 未安装")
                return .failed("手表端 App 未安装")
            }
            #endif

            try session.updateApplicationContext(dict)
            log("sendNotes: updateApplicationContext 已更新")

            session.transferUserInfo(dict)
            log("sendNotes: transferUserInfo 已发送")

            var message = "同步已排队，Watch 联机后会收到"

            if session.isReachable {
                session.sendMessage(dict, replyHandler: { reply in
                    self.log("sendNotes: sendMessage 回复: \(reply)")
                }) { error in
                    self.log("sendNotes: sendMessage 失败: \(error.localizedDescription)")
                }
                message = "同步请求已发送到 Watch"
            } else {
                log("sendNotes: 对端不可达，仅靠 transferUserInfo")
            }

            lastSentPayloadHash = payloadHash
            return .queued(message)
        } catch {
            log("sendNotes: 编码失败: \(error)")
            return .failed("同步失败：\(error.localizedDescription)")
        }
    }

    #if os(watchOS)
    func requestSyncFromWatch(reason: String = "manual") {
        log("requestSyncFromWatch: reason=\(reason)")
        requestLatestNotes(reason: reason)
    }

    private func requestLatestNotes(reason: String) {
        guard let session = session else {
            log("requestLatestNotes: session 为 nil")
            return
        }

        guard session.activationState == .activated else {
            log("requestLatestNotes: session 未激活，跳过请求")
            return
        }

        if let lastSyncRequestAt, Date().timeIntervalSince(lastSyncRequestAt) < 2 {
            log("requestLatestNotes: 请求过于频繁，跳过")
            return
        }
        lastSyncRequestAt = Date()

        let request: [String: Any] = [
            "type": "notes_sync_request",
            "timestamp": Date().timeIntervalSince1970
        ]

        log("requestLatestNotes: 请求最新笔记，原因: \(reason)")

        if session.isReachable {
            session.sendMessage(request, replyHandler: { reply in
                self.log("requestLatestNotes: sendMessage 回复: \(reply)")
            }) { error in
                self.log("requestLatestNotes: sendMessage 失败: \(error.localizedDescription)")
            }
        } else {
            session.transferUserInfo(request)
            log("requestLatestNotes: 对端不可达，已排队同步请求")
        }
    }
    #endif

    private func handleReceivedData(_ userInfo: [String: Any], source: String) {
        guard let type = userInfo["type"] as? String else {
            log("handleReceivedData: 收到 \(source) 数据但缺少 type, keys=\(userInfo.keys)")
            return
        }

        if type == "notes_sync_request" {
            log("handleReceivedData: 收到 \(source) 的同步请求")
            handleSyncRequest()
            return
        }

        guard let data = userInfo["data"] as? Data else {
            log("handleReceivedData: 收到 \(source) 数据但缺少 data, keys=\(userInfo.keys)")
            return
        }

        log("handleReceivedData: 收到 \(type) via \(source), \(data.count) bytes")

        if type == "notes_sync" {
            if let notes = try? JSONDecoder().decode([Note].self, from: data) {
                let payloadHash = notesPayloadHash(notes)
                if lastReceivedPayloadHash == payloadHash {
                    log("handleReceivedData: 内容未变化，跳过重复回调")
                    return
                }
                lastReceivedPayloadHash = payloadHash
                log("handleReceivedData: 解码成功 \(notes.count) 条笔记")
                DispatchQueue.main.async {
                    self.onNotesReceived?(notes)
                }
            } else {
                log("handleReceivedData: 解码失败")
            }
        }
    }

    private func handleSyncRequest() {
        guard let notesProvider = notesProvider else {
            log("handleSyncRequest: notesProvider 未注册，忽略同步请求")
            return
        }

        let notes = notesProvider()
        log("handleSyncRequest: 响应同步请求，发送 \(notes.count) 条笔记")
        _ = sendNotes(notes)
    }

    private func notesPayloadHash(_ notes: [Note]) -> Int {
        notes.reduce(into: Hasher()) { hasher, note in
            hasher.combine(note.id)
            hasher.combine(note.title)
            hasher.combine(note.content)
            hasher.combine(note.lastModified.timeIntervalSince1970)
        }.finalize()
    }
}

extension WatchSyncManager: WCSessionDelegate {

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        log("sessionDidBecomeInactive")
    }
    func sessionDidDeactivate(_ session: WCSession) {
        log("sessionDidDeactivate: 重新激活")
        WCSession.default.activate()
    }
    #endif

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        log("activationDidCompleteWith: state=\(activationState.rawValue), error=\(error?.localizedDescription ?? "无")")
        if activationState == .activated {
            isActivated = true
            if let pending = pendingNotes {
                pendingNotes = nil
                log("activationDidCompleteWith: 发送暂存的 \(pending.count) 条笔记")
                _ = sendNotes(pending, force: true)
            }
            #if os(watchOS)
            requestLatestNotes(reason: "sessionActivated")
            #endif
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        log("sessionReachabilityDidChange: reachable=\(session.isReachable)")
        #if os(watchOS)
        if session.isReachable && session.activationState == .activated {
            requestLatestNotes(reason: "becameReachable")
        }
        #endif
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        log("didReceiveApplicationContext")
        handleReceivedData(applicationContext, source: "applicationContext")
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        log("didReceiveUserInfo")
        handleReceivedData(userInfo, source: "userInfo")
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        log("didReceiveMessage")
        handleReceivedData(message, source: "message")
        replyHandler(["status": "ok"])
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        log("didReceiveFile")
        guard let data = try? Data(contentsOf: file.fileURL) else { return }
        handleReceivedData(["type": "notes_sync", "data": data], source: "file")
    }
}
