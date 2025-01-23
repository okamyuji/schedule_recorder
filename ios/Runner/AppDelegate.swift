import UIKit
import Flutter
import AVFoundation
import CallKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let channelName = "com.example.schedule_recorder/audio"
    private var wasRecordingInterrupted = false
    private var callCenter: CXCallObserver?
    private var methodChannel: FlutterMethodChannel?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        methodChannel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )
        
        setupAudioSession()
        setupCallObserver()
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // 着信音と共存できるように設定
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            try audioSession.setActive(true)
        } catch {
            debugPrint("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupCallObserver() {
        callCenter = CXCallObserver()
        callCenter?.setDelegate(self, queue: nil)
    }
}

extension AppDelegate: CXCallObserverDelegate {
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        guard let methodChannel = methodChannel else { return }
        
        if call.hasConnected {
            // 電話に出た時のみ録音を一時停止
            wasRecordingInterrupted = true
            methodChannel.invokeMethod("RecordingInterrupted", arguments: nil)
        } else if call.hasEnded && wasRecordingInterrupted {
            // 通話終了時に録音を再開
            wasRecordingInterrupted = false
            methodChannel.invokeMethod("RecordingResumed", arguments: nil)
        }
        // 着信時（call.isOutgoing == false && !call.hasConnected）は何もしない
    }
}
