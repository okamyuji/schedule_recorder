import Flutter
import UIKit
import AVFoundation
import CallKit
import Network

@main
@objc class AppDelegate: FlutterAppDelegate {
    // FlutterとのMethodChannel通信に使用する識別子
    private let channelName = "com.example.schedule_recorder/audio"
    // Flutterとの通信チャネル
    private var methodChannel: FlutterMethodChannel?
    // 通話状態の監視 (従来の実装との互換性のために維持)
    private var callObserver: CXCallObserver?
    // 通話状態を管理する
    private var isHandlingCall: Bool = false
    // SIP通話の監視用
    private var networkMonitor: NWPathMonitor?
    // SIPセッションの状態を監視
    private var sipSessionObserver: NSObjectProtocol?
    
    // CallKit Provider
    private var callKitProvider: CXProvider?
    private var callKitCallController: CXCallController?
    
    // SIP通話を識別するUUID
    private var currentSIPCallUUID: UUID?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // controllerの安全なアンラップ処理（強制アンラップを回避）
        guard let controller = window?.rootViewController as? FlutterViewController else {
            debugLog("Error: Could not get Flutter view controller")
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        
        methodChannel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )
        
        // Flutterからネイティブへのメソッド呼び出し
        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate is deallocated", details: nil))
                return
            }
            
            switch call.method {
            case "isPhoneCallActive":
                // アクティブな通話があるかどうかを確認
                let isActive = self.isHandlingCall
                result(isActive)
            case "ConfigureAudioSessionForRecording":
                // 録音に最適化されたオーディオセッションを設定
                self.configureAudioSessionForRecording()
                result(nil)
            case "VerifyFileExists":
                // ファイルの存在を確認
                if let args = call.arguments as? [String: Any],
                   let path = args["path"] as? String {
                    let fileExists = self.verifyFileExistsAndIsValid(path: path)
                    result(fileExists)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Path parameter required", details: nil))
                }
            case "GetFileInfo":
                // ファイル情報を取得
                if let args = call.arguments as? [String: Any],
                   let path = args["path"] as? String {
                    let fileInfo = self.getFileInfo(path: path)
                    result(fileInfo)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Path parameter required", details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        setupCallObserver()
        setupAudioSession()
        setupNetworkMonitor()
        setupSIPSessionObserver()
        setupCallKit() // CallKit統合のセットアップ

        debugLog("Application launched")

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // CallKitの設定
    private func setupCallKit() {
        let configuration = CXProviderConfiguration(localizedName: "Schedule Recorder")
        configuration.supportsVideo = false
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        
        callKitProvider = CXProvider(configuration: configuration)
        callKitProvider?.setDelegate(self, queue: nil)
        callKitCallController = CXCallController()
        
        debugLog("CallKit Provider setup completed")
    }
    
    override func applicationWillTerminate(_ application: UIApplication) {
        // クリーンアップ：リソースリークを防ぐために監視を停止
        cleanupResources()
        super.applicationWillTerminate(application)
    }
    
    private func cleanupResources() {
        // NetworkMonitorのクリーンアップ
        networkMonitor?.cancel()
        networkMonitor = nil
        
        // SIPセッション監視のクリーンアップ
        if let observer = sipSessionObserver {
            NotificationCenter.default.removeObserver(observer)
            sipSessionObserver = nil
        }
        
        // CallKitプロバイダーのクリーンアップ
        if let provider = callKitProvider {
            provider.invalidate()
            callKitProvider = nil
        }
        
        callKitCallController = nil
        
        debugLog("Resources cleaned up")
    }

    private func setupCallObserver() {
        callObserver = CXCallObserver()
        callObserver?.setDelegate(self, queue: nil)
        debugLog("CallObserver setup completed")
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat, // SIPと通常の通話の両方に最適化
                options: [.defaultToSpeaker, .allowBluetooth, .allowAirPlay]
            )
            try session.setActive(true)
            debugLog("Audio session setup completed with VoIP optimization")
        } catch {
            debugLog("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    /// 録音用にオーディオセッションを最適化
    private func configureAudioSessionForRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            
            // まずセッションを非アクティブにして通話状態をクリア
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            
            // 録音に最適化されたカテゴリとモードを設定
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            
            // セッションを再びアクティブ化
            try session.setActive(true)
            
            debugLog("Audio session reconfigured specifically for recording")
        } catch {
            debugLog("Failed to reconfigure audio session for recording: \(error.localizedDescription)")
        }
    }
    
    /// ファイルの存在と有効性を確認
    private func verifyFileExistsAndIsValid(path: String) -> Bool {
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: path)
        
        if exists {
            debugLog("File exists at path: \(path)")
            
            // ファイルサイズを確認
            do {
                let attributes = try fileManager.attributesOfItem(atPath: path)
                if let size = attributes[.size] as? UInt64 {
                    debugLog("File size: \(size) bytes")
                    return size > 0 // ファイルサイズが0より大きければ有効とみなす
                }
            } catch {
                debugLog("Failed to get file attributes: \(error.localizedDescription)")
            }
        } else {
            debugLog("File does NOT exist at path: \(path)")
        }
        
        return exists
    }
    
    /// ファイルの情報を取得
    private func getFileInfo(path: String) -> [String: Any] {
        var info: [String: Any] = [:]
        let fileManager = FileManager.default
        
        do {
            if fileManager.fileExists(atPath: path) {
                // ファイルの属性を取得
                let attributes = try fileManager.attributesOfItem(atPath: path)
                
                // サイズ情報
                if let size = attributes[.size] as? UInt64 {
                    info["size"] = Int(size)
                    debugLog("File size: \(size) bytes")
                }
                
                // 更新日時
                if let modificationDate = attributes[.modificationDate] as? Date {
                    info["modificationDate"] = modificationDate.timeIntervalSince1970
                }
                
                // ファイル作成日時
                if let creationDate = attributes[.creationDate] as? Date {
                    info["creationDate"] = creationDate.timeIntervalSince1970
                }
                
                info["exists"] = true
            } else {
                info["exists"] = false
                debugLog("File does not exist at path: \(path)")
            }
        } catch {
            debugLog("Error getting file info: \(error.localizedDescription)")
            info["error"] = error.localizedDescription
        }
        
        return info
    }
    
    
    private func setupNetworkMonitor() {
        networkMonitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                self?.debugLog("Network is available for SIP calls")
            } else {
                self?.debugLog("Network unavailable, SIP calls may not function")
            }
        }
        
        networkMonitor?.start(queue: queue)
        debugLog("Network monitor for SIP calls started")
    }
    
    private func setupSIPSessionObserver() {
        // ST500などのSIPセッション状態の監視を設定
        // NotificationCenterを使用して特定のVoIPセッション通知を監視
        sipSessionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self = self else { return }
            
            if let userInfo = notification.userInfo,
               let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
               let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) {
                
                switch reason {
                case .newDeviceAvailable:
                    self.handleNewAudioDeviceConnected()
                case .oldDeviceUnavailable:
                    self.handleAudioDeviceDisconnected()
                default:
                    break
                }
            }
        }
        
        debugLog("SIP session observer setup completed")
    }
    
    // 新しいオーディオデバイス接続時の処理
    private func handleNewAudioDeviceConnected() {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute
        var sipDeviceDetected = false
        
        // 接続されたデバイスのログを詳細に出力
        debugLog("Audio device connection detected. Current route outputs:")
        for output in currentRoute.outputs {
            debugLog("- Device: \(output.portName), Type: \(output.portType.rawValue)")
        }
        
        // 接続されたデバイスがSIPデバイスかチェック
        for output in currentRoute.outputs where isSIPDevice(output: output) {
            sipDeviceDetected = true
            debugLog("SIP device (VoIP) connected: \(output.portName), Type: \(output.portType.rawValue)")
            
            // CallKit経由でSIP通話開始を報告
            reportSIPCallStarted(deviceName: output.portName)
            break
        }
        
        if sipDeviceDetected {
            // 実際の通話が開始されたかどうかを確認するために遅延チェックを実施
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.checkSIPCallAudioStarted()
            }
        } else {
            debugLog("Connected device is not a SIP/VoIP device")
        }
    }
    
    // SIP通話のオーディオが実際に開始されたかチェック
    private func checkSIPCallAudioStarted() {
        let audioSession = AVAudioSession.sharedInstance()
        
        if audioSession.isOtherAudioPlaying {
            debugLog("SIP call audio confirmed - audio session is active")
            
            // 録音中で通話中でない場合は一時停止
            methodChannel?.invokeMethod("GetRecordState", arguments: nil) { [weak self] result in
                guard let self = self else { return }
                
                let recordState = (result as? String) ?? "unknown"
                if recordState == "record" && !self.isHandlingCall {
                    self.debugLog("SIP call active during recording, pausing recording")
                    self.methodChannel?.invokeMethod("RecordingInterrupted", arguments: nil)
                    self.isHandlingCall = true
                } else {
                    self.debugLog("Current recording state during SIP call: \(recordState), isHandlingCall: \(self.isHandlingCall)")
                }
            }
        } else {
            debugLog("SIP device connected but no audio session activity detected")
            // オーディオセッションがすぐに開始されない場合があるため、再度チェック
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                
                let audioSession = AVAudioSession.sharedInstance()
                if audioSession.isOtherAudioPlaying {
                    self.debugLog("SIP call audio detected after extended delay")
                    self.checkAndInterruptRecording()
                } else {
                    self.debugLog("No SIP call audio detected after extended delay")
                }
            }
        }
    }
    
    // オーディオデバイス切断時の処理（改善版）
    private func handleAudioDeviceDisconnected() {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute
        let isAudioPlaying = audioSession.isOtherAudioPlaying
        
        debugLog("Audio device disconnection detected.")
        debugLog("Current isOtherAudioPlaying: \(isAudioPlaying)")
        debugLog("Current isHandlingCall: \(isHandlingCall)")
        debugLog("Current SIP call UUID exists: \(currentSIPCallUUID != nil)")
        
        // SIP通話終了を報告
        if currentSIPCallUUID != nil {
            debugLog("SIP call in progress, reporting call ended")
            reportSIPCallEnded()
        }
        
        // 録音が一時停止中かつ通話処理中の場合にのみ再開を試みる
        methodChannel?.invokeMethod("GetRecordState", arguments: nil) { [weak self] result in
            guard let self = self else { return }
            
            let recordState = (result as? String) ?? "unknown"
            self.debugLog("Current recording state on device disconnect: \(recordState)")
            
            if recordState == "pause" && self.isHandlingCall {
                // オーディオセッションが完全に終了したことを確認するため少し待ってから処理
                self.debugLog("Recording is paused due to SIP call, preparing to resume")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    
                    let audioSession = AVAudioSession.sharedInstance()
                    if !audioSession.isOtherAudioPlaying {
                        self.debugLog("SIP call audio confirmed ended, resuming recording")
                        self.methodChannel?.invokeMethod("RecordingResumed", arguments: nil)
                        self.debugLog("Resume command sent, confirming state in 1 second")
                        
                        // 録音が実際に再開されたか確認
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                            guard let self = self else { return }
                            
                            self.methodChannel?.invokeMethod("GetRecordState", arguments: nil) { result in
                                let stateAfterResume = (result as? String) ?? "unknown"
                                self.debugLog("Recording state after resume attempt: \(stateAfterResume)")
                                self.resetCallState()
                            }
                        }
                    } else {
                        self.debugLog("Audio still active after device disconnect, not resuming recording yet")
                        self.resetCallState()
                    }
                }
            } else {
                if recordState == "pause" {
                    self.debugLog("Recording paused but not handling a call, not resuming")
                } else {
                    self.debugLog("Recording not paused, no action needed")
                }
                self.resetCallState()
            }
        }
    }
    
    // CallKitにSIP通話の開始を報告する
    private func reportSIPCallStarted(deviceName: String) {
        // 既存の通話がある場合は終了としてマーク
        if let existingCallUUID = currentSIPCallUUID {
            debugLog("Existing SIP call found, ending previous call before reporting new one")
            endCall(uuid: existingCallUUID)
        }
        
        // 新しい通話UUIDを生成
        let uuid = UUID()
        currentSIPCallUUID = uuid
        
        // 通話情報を設定（より詳細な情報を含める）
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: "VoIP Call")
        update.localizedCallerName = "VoIP: \(deviceName)"
        update.hasVideo = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
        update.supportsDTMF = false
        
        // CallKitに通話を報告
        callKitProvider?.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            if let error = error {
                self?.debugLog("Failed to report SIP/VoIP call to CallKit: \(error.localizedDescription)")
            } else {
                self?.debugLog("SIP/VoIP call reported to CallKit successfully with UUID: \(uuid)")
            }
        }
    }
    
    // CallKitにSIP通話の終了を報告する
    private func reportSIPCallEnded() {
        guard let uuid = currentSIPCallUUID else { return }
        
        endCall(uuid: uuid)
        currentSIPCallUUID = nil
        debugLog("SIP call ended and reported to CallKit")
    }
    
    // 指定されたUUIDの通話を終了する
    private func endCall(uuid: UUID) {
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        callKitCallController?.request(transaction) { [weak self] error in
            if let error = error {
                self?.debugLog("Failed to end call: \(error.localizedDescription)")
            } else {
                self?.debugLog("Call ended successfully")
            }
        }
    }

    // デバッグログ出力
    private func debugLog(_ message: String) {
        // 即座にコンソールに出力
        print("[ScheduleRecorder/Native] \(message)")
        // システムログに出力
        NSLog("[ScheduleRecorder/Native] %@", message)
        // Flutterにログを送信
        DispatchQueue.main.async {
            self.methodChannel?.invokeMethod("debugLog", arguments: message)
        }
    }

    private func resetCallState() {
        let wasHandlingCall = isHandlingCall
        isHandlingCall = false
        debugLog("Call state reset: wasHandlingCall=\(wasHandlingCall), now=\(isHandlingCall)")
    }
}

extension AppDelegate: CXCallObserverDelegate {
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        if call.hasEnded {
            handleCallEnded()
        } else if !call.isOutgoing && call.hasConnected {
            handleIncomingCallConnected()
        } else if call.isOutgoing && call.hasConnected {
            handleOutgoingCallConnected()
        }
    }
    
    // 通話終了時の処理
    private func handleCallEnded() {
        debugLog("CXCallObserver - Call ended, current isHandlingCall: \(isHandlingCall)")

        // 録音状態を確認
        methodChannel?.invokeMethod("GetRecordState", arguments: nil) { [weak self] result in
            guard let self = self else { return }
            
            let recordState = (result as? String) ?? "unknown"
            self.debugLog("Current record state: \(recordState)")

            // 録音が一時停止状態のときは基本的に再開を試みる（安全のため）
            if recordState == "pause" {
                // isHandlingCallフラグに関わらず試みる（トラブルシューティングのため）
                if self.isHandlingCall {
                    self.debugLog("Recording is paused due to call, attempting to resume")
                } else {
                    self.debugLog("Recording is paused (possibly due to a call), attempting to resume anyway")
                    // 念のためフラグを設定
                    self.isHandlingCall = true
                }
                self.startRecordingResumeAttempts()
            } else {
                self.debugLog("Recording is not paused (state: \(recordState)), no need to resume")
                self.resetCallState()
            }
        }
    }
    
    // 通話再開試行の改善・簡素化版
    private func startRecordingResumeAttempts() {
        // isHandlingCallフラグが確実にセットされていることを確認
        if !isHandlingCall {
            debugLog("WARNING: isHandlingCall was false in startRecordingResumeAttempts, fixing...")
            isHandlingCall = true
        }
        
        debugLog("Starting recording resume attempts, isHandlingCall: \(isHandlingCall)")
        
        // 最初の試行のために少し待機
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // オーディオセッションが完全に終了していることを確認
            let audioSession = AVAudioSession.sharedInstance()
            if audioSession.isOtherAudioPlaying || self.isSIPCallActive() {
                self.debugLog("Audio session still active, waiting more before resuming")
                
                // 少し待ってからもう一度試す
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    
                    let audioSession = AVAudioSession.sharedInstance()
                    if !audioSession.isOtherAudioPlaying && !self.isSIPCallActive() {
                        self.directlyResumeRecording()
                    } else {
                        self.debugLog("Audio still active after extended wait, giving up")
                        self.resetCallState()
                    }
                }
                return
            }
            
            // 録音を再開
            self.directlyResumeRecording()
        }
    }
    
    // 録音を直接再開する（シンプルかつ確実なアプローチ）
    private func directlyResumeRecording() {
        debugLog("Attempting to resume recording with enhanced method")
        
        // 1. まずオーディオセッションを完全にリセット
        configureAudioSessionForRecording()
        
        // 2. Flutter側のレコーダー状態を確認
        methodChannel?.invokeMethod("GetRecordState", arguments: nil) { [weak self] result in
            guard let self = self else { return }
            let stateBefore = (result as? String) ?? "unknown"
            self.debugLog("Recording state BEFORE resume attempt: \(stateBefore)")
            
            if stateBefore != "pause" {
                self.debugLog("WARNING: Recording was not in pause state before resume attempt: \(stateBefore)")
                if stateBefore == "record" {
                    self.debugLog("Recording already in record state, skipping resume")
                    self.resetCallState()
                    return
                }
            }
            
            // 3. 録音再開を通知
            self.methodChannel?.invokeMethod("RecordingResumed", arguments: nil)
            self.debugLog("Sent recording resume signal")
            
            // 4. 少し待ってから状態を確認
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                
                self.methodChannel?.invokeMethod("GetRecordState", arguments: nil) { result in
                    let stateAfter = (result as? String) ?? "unknown"
                    self.debugLog("Recording state after resume: \(stateAfter)")
                    
                    if stateAfter == "record" {
                        self.debugLog("SUCCESS: Recording successfully resumed")
                    } else {
                        self.debugLog("WARNING: Recording not in record state after resume, trying again")
                        
                        // もう一度試す
                        self.methodChannel?.invokeMethod("RecordingResumed", arguments: nil)
                        self.debugLog("Sent second resume signal")
                    }
                    
                    // 状態をリセット
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.resetCallState()
                    }
                }
            }
        }
    }

    // 着信通話接続時の処理
    private func handleIncomingCallConnected() {
        // 着信時の状態を詳細にログ出力
        debugLog("CXCallObserver - Incoming call state changed")
        debugLog("isOutgoing: false")
        debugLog("hasConnected: true")

        let audioSession = AVAudioSession.sharedInstance()
        // 実際の通話が確立されているかを確認
        if audioSession.isOtherAudioPlaying {
            checkAndInterruptRecording()
        } else {
            // 通話が確立されていない場合(留守電など)は録音を継続
            debugLog("CXCallObserver - Call is not yet fully connected (possibly voicemail)")
            debugLog("Current audio session state - isOtherAudioPlaying: \(audioSession.isOtherAudioPlaying)")
            
            // 遅延チェックを追加（通話オーディオが少し遅れて開始することがあるため）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.checkDelayedCallAudio()
            }
        }
    }
    
    // 通話オーディオの遅延チェック
    private func checkDelayedCallAudio() {
        let audioSession = AVAudioSession.sharedInstance()
        // 遅延して通話オーディオが開始されたかを確認
        if audioSession.isOtherAudioPlaying {
            debugLog("CXCallObserver - Call audio detected after delay, now pausing recording")
            checkAndInterruptRecording()
        } else {
            debugLog("CXCallObserver - No call audio detected after delay, continuing recording")
        }
    }
    
    // 録音状態を確認して適切に中断する
    private func checkAndInterruptRecording() {
        // 通話処理中フラグを最初に設定（これが重要）
        isHandlingCall = true
        debugLog("Set isHandlingCall to true BEFORE checking recording state")
        
        // 現在の録音状態を確認
        methodChannel?.invokeMethod("GetRecordState", arguments: nil) { [weak self] result in
            guard let self = self else { return }
            
            let recordState = (result as? String) ?? "unknown"
            if recordState == "record" {
                debugLog("CXCallObserver - Call is actually connected, pausing recording")
                methodChannel?.invokeMethod("RecordingInterrupted", arguments: nil)
                debugLog("RecordingInterrupted method invoked, confirmed isHandlingCall: \(self.isHandlingCall)")
            } else {
                debugLog("CXCallObserver - Call is connected but recording is not in progress (state: \(recordState))")
                if recordState == "pause" {
                    // 既に一時停止中の場合も通話処理中としてマーク
                    debugLog("Recording already paused, marking as handling call for later resume")
                }
            }
        }
    }
    
    // 発信通話接続時の処理
    private func handleOutgoingCallConnected() {
        debugLog("CXCallObserver - Outgoing call connected")
        // 発信の場合も同様に実際の通話状態を確認
        let audioSession = AVAudioSession.sharedInstance()
        if audioSession.isOtherAudioPlaying {
            checkAndInterruptRecording()
        } else {
            debugLog("CXCallObserver - Outgoing call connected but no audio detected yet")
            // 遅延チェックを追加
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.checkDelayedCallAudio()
            }
        }
    }
    
    // SIP通話が現在アクティブかどうかを確認
    private func isSIPCallActive() -> Bool {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute
        
        // ST500などのSIPデバイスがアクティブかチェック
        for output in currentRoute.outputs where isSIPDevice(output: output) && audioSession.isOtherAudioPlaying {
            debugLog("Active SIP call detected on device: \(output.portName)")
            return true
        }
        
        return false
    }
    
    // 指定されたオーディオ出力がSIPデバイスかどうかを判断（改善版）
    private func isSIPDevice(output: AVAudioSessionPortDescription) -> Bool {
        // デバッグログへの詳細出力
        debugLog("Checking if device is SIP/VoIP: \(output.portName), type: \(output.portType.rawValue)")
        
        // ポートタイプによる検出
        let sipPortTypes: [AVAudioSession.Port] = [
            .usbAudio,        // USB接続のVoIPデバイス
            .headphones,      // ヘッドセット（可能性がある）
            .bluetoothA2DP,   // BluetoothオーディオデバイスでVoIPに使われる可能性がある
            .bluetoothHFP,    // Bluetooth Hands-Free Profile - VoIP通話によく使われる
            .bluetoothLE,     // Bluetooth Low Energy - 一部のVoIPデバイスで使用
            .lineIn           // 一部のVoIPデバイスがライン入力として認識される
        ]
        
        // 名前による検出（大文字小文字を区別しない）
        let sipNameKeywords = [
            "st500", "sip", "voip", "ip phone", "softphone", 
            "conference", "webex", "zoom", "teams", "cisco", 
            "avaya", "polycom", "headset", "bluetooth"
        ]
        
        // ポートタイプかキーワードマッチで検出
        let portTypeMatch = sipPortTypes.contains(output.portType)
        let nameMatch = sipNameKeywords.contains { keyword in
            output.portName.lowercased().contains(keyword)
        }
        
        // マッチした理由をログに出力
        if portTypeMatch {
            debugLog("Device matched as SIP device by port type: \(output.portType.rawValue)")
        }
        if nameMatch {
            debugLog("Device matched as SIP device by name keywords")
        }
        
        return portTypeMatch || nameMatch
    }
}

// CallKitのプロバイダーデリゲート実装
extension AppDelegate: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        debugLog("Provider did reset")
        // 通話関連の状態をリセット
        currentSIPCallUUID = nil
        isHandlingCall = false
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        // 通話に応答するアクション
        debugLog("Call answered via CallKit")
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        // 通話を終了するアクション
        debugLog("Call ended via CallKit")
        
        // 録音が一時停止中だった場合は再開
        methodChannel?.invokeMethod("GetRecordState", arguments: nil) { [weak self] result in
            guard let self = self else { return }
            
            let recordState = (result as? String) ?? "unknown"
            if recordState == "pause" {
                self.debugLog("Recording was paused, attempting to resume after call end")
                // すぐには再開せず、少し待機して他のオーディオソースがないか確認
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    let audioSession = AVAudioSession.sharedInstance()
                    
                    if !audioSession.isOtherAudioPlaying && !self.isSIPCallActive() {
                        self.methodChannel?.invokeMethod("RecordingResumed", arguments: nil)
                        self.debugLog("Recording resumed after confirming no active calls")
                    }
                }
            }
        }
        
        resetCallState()
        currentSIPCallUUID = nil
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        // 通話の保留状態を変更するアクション
        debugLog("Call hold status changed via CallKit: \(action.isOnHold)")
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        // 発信を開始するアクション
        debugLog("Call started via CallKit")
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // オーディオセッションがアクティブになった
        debugLog("Audio session activated by CallKit")
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        // オーディオセッションが非アクティブになった
        debugLog("Audio session deactivated by CallKit")
        
        // 必要に応じてオーディオセッションを再構成
        setupAudioSession()
    }
}
