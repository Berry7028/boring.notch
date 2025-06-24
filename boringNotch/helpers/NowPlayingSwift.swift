//
//  NowPlayingSwift.swift
//  boringNotch
//
//  Created by OpenHands on 24/06/25.
//

import Foundation
import Cocoa

@objc class NowPlaying: NSObject {
    @objc static let sharedInstance = NowPlaying()
    
    @objc var appBundleIdentifier: String?
    @objc var appName: String?
    @objc var appIcon: NSImage?
    @objc var album: String?
    @objc var artist: String?
    @objc var title: String?
    @objc var playing: Bool = false
    
    private var mediaRemoteBundle: CFBundle?
    private var mrMediaRemoteGetNowPlayingClient: (@convention(c) (DispatchQueue, @escaping (AnyObject?) -> Void) -> Void)?
    private var mrMediaRemoteGetNowPlayingInfo: (@convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void)?
    private var mrMediaRemoteGetNowPlayingApplicationIsPlaying: (@convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void)?
    private var mrNowPlayingClientGetBundleIdentifier: (@convention(c) (AnyObject) -> String?)?
    private var mrNowPlayingClientGetParentAppBundleIdentifier: (@convention(c) (AnyObject) -> String?)?
    
    // Constants for notification names
    private let kMRMediaRemoteNowPlayingApplicationDidChangeNotification = "kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
    private let kMRMediaRemoteNowPlayingApplicationClientStateDidChange = "kMRMediaRemoteNowPlayingApplicationClientStateDidChange"
    private let kMRNowPlayingPlaybackQueueChangedNotification = "kMRNowPlayingPlaybackQueueChangedNotification"
    private let kMRPlaybackQueueContentItemsChangedNotification = "kMRPlaybackQueueContentItemsChangedNotification"
    private let kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification = "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"
    
    // Constants for info dictionary keys
    private let kMRMediaRemoteNowPlayingInfoAlbum = "kMRMediaRemoteNowPlayingInfoAlbum"
    private let kMRMediaRemoteNowPlayingInfoArtist = "kMRMediaRemoteNowPlayingInfoArtist"
    private let kMRMediaRemoteNowPlayingInfoTitle = "kMRMediaRemoteNowPlayingInfoTitle"
    
    override init() {
        super.init()
        
        // Load MediaRemote framework
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")) else {
            print("Failed to load MediaRemote.framework")
            return
        }
        
        mediaRemoteBundle = bundle
        
        // Get function pointers
        guard let mrMediaRemoteRegisterForNowPlayingNotificationsPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString),
              let mrMediaRemoteGetNowPlayingClientPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingClient" as CFString),
              let mrMediaRemoteGetNowPlayingInfoPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString),
              let mrMediaRemoteGetNowPlayingApplicationIsPlayingPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString),
              let mrNowPlayingClientGetBundleIdentifierPointer = CFBundleGetFunctionPointerForName(bundle, "MRNowPlayingClientGetBundleIdentifier" as CFString),
              let mrNowPlayingClientGetParentAppBundleIdentifierPointer = CFBundleGetFunctionPointerForName(bundle, "MRNowPlayingClientGetParentAppBundleIdentifier" as CFString)
        else {
            print("Failed to get function pointers from MediaRemote.framework")
            return
        }
        
        // Cast function pointers to Swift function types
        let mrMediaRemoteRegisterForNowPlayingNotifications = unsafeBitCast(
            mrMediaRemoteRegisterForNowPlayingNotificationsPointer,
            to: (@convention(c) (DispatchQueue) -> Void).self
        )
        
        mrMediaRemoteGetNowPlayingClient = unsafeBitCast(
            mrMediaRemoteGetNowPlayingClientPointer,
            to: (@convention(c) (DispatchQueue, @escaping (AnyObject?) -> Void) -> Void).self
        )
        
        mrMediaRemoteGetNowPlayingInfo = unsafeBitCast(
            mrMediaRemoteGetNowPlayingInfoPointer,
            to: (@convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void).self
        )
        
        mrMediaRemoteGetNowPlayingApplicationIsPlaying = unsafeBitCast(
            mrMediaRemoteGetNowPlayingApplicationIsPlayingPointer,
            to: (@convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void).self
        )
        
        mrNowPlayingClientGetBundleIdentifier = unsafeBitCast(
            mrNowPlayingClientGetBundleIdentifierPointer,
            to: (@convention(c) (AnyObject) -> String?).self
        )
        
        mrNowPlayingClientGetParentAppBundleIdentifier = unsafeBitCast(
            mrNowPlayingClientGetParentAppBundleIdentifierPointer,
            to: (@convention(c) (AnyObject) -> String?).self
        )
        
        // Register for notifications
        mrMediaRemoteRegisterForNowPlayingNotifications(DispatchQueue.main)
        
        // Set up notification observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidChange),
            name: NSNotification.Name(kMRMediaRemoteNowPlayingApplicationDidChangeNotification),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(infoDidChange),
            name: NSNotification.Name(kMRMediaRemoteNowPlayingApplicationClientStateDidChange),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(infoDidChange),
            name: NSNotification.Name(kMRNowPlayingPlaybackQueueChangedNotification),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(infoDidChange),
            name: NSNotification.Name(kMRPlaybackQueueContentItemsChangedNotification),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playingDidChange),
            name: NSNotification.Name(kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification),
            object: nil
        )
        
        // Initial updates
        updateApp()
        updateInfo()
        updateState()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func updateApp() {
        guard let mrMediaRemoteGetNowPlayingClient = mrMediaRemoteGetNowPlayingClient,
              let mrNowPlayingClientGetBundleIdentifier = mrNowPlayingClientGetBundleIdentifier,
              let mrNowPlayingClientGetParentAppBundleIdentifier = mrNowPlayingClientGetParentAppBundleIdentifier else {
            return
        }
        
        mrMediaRemoteGetNowPlayingClient(DispatchQueue.main) { [weak self] clientObj in
            guard let self = self, let clientObj = clientObj else { return }
            
            var appBundleIdentifier: String? = nil
            var appName: String? = nil
            var appIcon: NSImage? = nil
            
            // Get bundle identifier
            appBundleIdentifier = mrNowPlayingClientGetParentAppBundleIdentifier(clientObj)
            if appBundleIdentifier == nil {
                appBundleIdentifier = mrNowPlayingClientGetBundleIdentifier(clientObj)
            }
            
            // Get app name and icon
            if let bundleId = appBundleIdentifier {
                if let path = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleId) {
                    appName = FileManager.default.displayName(atPath: path)
                    appIcon = NSWorkspace.shared.icon(forFile: path)
                }
            }
            
            // Handle special case for Safari
            if appBundleIdentifier == "com.apple.WebKit.GPU" {
                appBundleIdentifier = "com.apple.Safari"
            }
            
            // Update properties if changed
            let changed = self.appBundleIdentifier != appBundleIdentifier ||
                         self.appName != appName ||
                         self.appIcon != appIcon
            
            if changed {
                self.appBundleIdentifier = appBundleIdentifier
                self.appName = appName
                self.appIcon = appIcon
                
                // Post notification
                NotificationCenter.default.post(name: NSNotification.Name(NowPlayingInfoNotification), object: self)
            }
        }
    }
    
    @objc func updateInfo() {
        guard let mrMediaRemoteGetNowPlayingInfo = mrMediaRemoteGetNowPlayingInfo else {
            return
        }
        
        mrMediaRemoteGetNowPlayingInfo(DispatchQueue.main) { [weak self] info in
            guard let self = self else { return }
            
            let album = info[self.kMRMediaRemoteNowPlayingInfoAlbum] as? String
            let artist = info[self.kMRMediaRemoteNowPlayingInfoArtist] as? String
            let title = info[self.kMRMediaRemoteNowPlayingInfoTitle] as? String
            
            // Update properties if changed
            let changed = self.album != album || self.artist != artist || self.title != title
            
            if changed {
                self.album = album
                self.artist = artist
                self.title = title
                
                // Post notification
                NotificationCenter.default.post(name: NSNotification.Name(NowPlayingInfoNotification), object: self)
            }
        }
    }
    
    @objc func updateState() {
        guard let mrMediaRemoteGetNowPlayingApplicationIsPlaying = mrMediaRemoteGetNowPlayingApplicationIsPlaying else {
            return
        }
        
        mrMediaRemoteGetNowPlayingApplicationIsPlaying(DispatchQueue.main) { [weak self] playing in
            guard let self = self else { return }
            
            // Update property if changed
            if self.playing != playing {
                self.playing = playing
                
                // Post notification
                NotificationCenter.default.post(name: NSNotification.Name(NowPlayingStateNotification), object: self)
            }
        }
    }
    
    @objc func appDidChange(_ notification: Notification) {
        updateApp()
    }
    
    @objc func infoDidChange(_ notification: Notification) {
        updateInfo()
    }
    
    @objc func playingDidChange(_ notification: Notification) {
        updateState()
    }
}

// Notification names
let NowPlayingInfoNotification = "NowPlayingInfo"
let NowPlayingStateNotification = "NowPlayingState"