import UIKit
import Social
import MobileCoreServices
import os.log
import UniformTypeIdentifiers
import receive_sharing_intent

struct SharedMediaFile {
    let path: String
    let thumbnail: String?
    let duration: Double?
    let type: String
    
    func toDict() -> [String: Any] {
        var dict: [String: Any] = [
            "path": path,
            "type": type
        ]
        if let thumbnail = thumbnail {
            dict["thumbnail"] = thumbnail
        }
        if let duration = duration {
            dict["duration"] = duration
        }
        return dict
    }
}

class ShareViewController: SLComposeServiceViewController {
    private let logger = OSLog(subsystem: "com.example.scheduleRecorder.ShareExtension", category: "ShareViewController")
    private var sharedMedia: [SharedMediaFile] = []
    private let hostAppBundleIdentifier = "com.example.scheduleRecorder"
    private let sharedKey = "ShareKey"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("ShareViewController: viewDidLoad called", log: logger, type: .debug)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        os_log("ShareViewController: viewDidAppear called", log: logger, type: .debug)
        processAttachments()
    }
    
    private func processAttachments() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            os_log("ShareViewController: No input items found", log: logger, type: .error)
            completeRequest()
            return
        }
        
        os_log("ShareViewController: Found %{public}d extension items", log: logger, type: .debug, extensionItems.count)
        
        var remainingItems = extensionItems.count
        
        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else {
                os_log("ShareViewController: No attachments found in item", log: logger, type: .error)
                remainingItems -= 1
                if remainingItems == 0 {
                    completeRequest()
                }
                continue
            }
            
            os_log("ShareViewController: Processing %{public}d attachments", log: logger, type: .debug, attachments.count)
            
            var remainingAttachments = attachments.count
            
            for attachment in attachments {
                os_log("ShareViewController: Attachment types: %{public}@", log: logger, type: .debug, attachment.registeredTypeIdentifiers)
                
                if attachment.hasItemConformingToTypeIdentifier(kUTTypeAudio as String) ||
                    attachment.hasItemConformingToTypeIdentifier(kUTTypeMP3 as String) ||
                    attachment.hasItemConformingToTypeIdentifier(kUTTypeMPEG4Audio as String) ||
                    attachment.hasItemConformingToTypeIdentifier("public.wav") {
                    
                    attachment.loadItem(forTypeIdentifier: attachment.registeredTypeIdentifiers[0], options: nil) { [weak self] data, error in
                        guard let self = self else { return }
                        
                        defer {
                            remainingAttachments -= 1
                            if remainingAttachments == 0 {
                                remainingItems -= 1
                                if remainingItems == 0 {
                                    self.completeRequest()
                                }
                            }
                        }
                        
                        if let error = error {
                            os_log("ShareViewController: Error loading attachment: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                            return
                        }
                        
                        guard let url = data as? URL else {
                            os_log("ShareViewController: Invalid data type received", log: self.logger, type: .error)
                            return
                        }
                        
                        os_log("ShareViewController: Processing audio file at path: %{public}@", log: self.logger, type: .debug, url.path)
                        
                        self.processFile(at: url)
                    }
                } else {
                    remainingAttachments -= 1
                    if remainingAttachments == 0 {
                        remainingItems -= 1
                        if remainingItems == 0 {
                            completeRequest()
                        }
                    }
                }
            }
        }
    }
    
    private func processFile(at url: URL) {
        os_log("ShareViewController: Starting to process file: %{public}@", log: logger, type: .debug, url.lastPathComponent)
        
        let sharedMediaFile = SharedMediaFile(path: url.path, thumbnail: nil, duration: nil, type: "audio")
        sharedMedia.append(sharedMediaFile)
        
        os_log("ShareViewController: Added file to shared media files: %{public}@", log: logger, type: .debug, url.lastPathComponent)
    }
    
    private func completeRequest() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            os_log("ShareViewController: Completing request", log: logger, type: .debug)
            self.saveAndRedirect()
        }
    }
    
    private func saveAndRedirect() {
        let userDefaults = UserDefaults(suiteName: "group.\(hostAppBundleIdentifier)")
        userDefaults?.set(sharedMedia.map { $0.toDict() }, forKey: sharedKey)
        userDefaults?.synchronize()
        
        let url = URL(string: "\(hostAppBundleIdentifier)://dataUrl=\(sharedKey)")!
        var responder = self as UIResponder?
        let selectorOpenURL = sel_registerName("openURL:")
        
        while responder != nil {
            if responder?.responds(to: selectorOpenURL) == true {
                responder?.perform(selectorOpenURL, with: url)
                break
            }
            responder = responder?.next
        }
        
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    override func isContentValid() -> Bool {
        os_log("ShareViewController: isContentValid called", log: logger, type: .debug)
        return true
    }
    
    override func didSelectPost() {
        os_log("ShareViewController: didSelectPost called", log: logger, type: .debug)
        completeRequest()
    }
    
    override func configurationItems() -> [Any]! {
        os_log("ShareViewController: configurationItems called", log: logger, type: .debug)
        return []
    }
}