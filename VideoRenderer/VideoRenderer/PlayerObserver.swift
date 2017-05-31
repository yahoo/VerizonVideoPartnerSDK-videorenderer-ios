//  Copyright © 2016 One by Aol : Publishers. All rights reserved.

import Foundation
import AVFoundation

public final class PlayerObserver: NSObject {
    public struct Callbacks {
        public var unknownState: Action<Void>?
        public var readyState: Action<AVPlayerItem>?
        public var failedState: Action<Error>?
        public var rateChanged: Action<(newRate: Float, oldRate: Float?)>?
        public var durationDefined: Action<(duration: CMTime, forItem: AVPlayerItem)>?
        public var endOfVideo: Action<Void>?
        public var playbackReady: Action<Bool>?
        public var bufferedTimeUpdated: Action<CMTime>?
        
        public init() {}
    }
    
    private let callbacks: Callbacks
    private var removeObserver: (PlayerObserver) -> ()
    private var tracker: SystemPlayer.Tracker?
    
    //swiftlint:disable function_body_length
    public init(callbacks: Callbacks, player: AVPlayer) {
        self.callbacks = callbacks
        //tracker = SystemPlayer.Tracker(player: player)
        removeObserver = { _ in }
        
        guard let currentItem = player.currentItem else {
            fatalError("Player with item is required")
        }
        
        super.init()
        
        player.addObserver(
            self,
            forKeyPath: "rate",
            options: [.initial, .new, .old],
            context: &Context.rate)
        currentItem.addObserver(
            self,
            forKeyPath: "status",
            options: [.initial, .new, .old],
            context: &Context.item)
        player.addObserver(
            self,
            forKeyPath: "currentItem.playbackBufferFull",
            options: [.initial, .new, .old],
            context: &Context.buffer)
        player.addObserver(
            self,
            forKeyPath: "currentItem.playbackLikelyToKeepUp",
            options: [.initial, .new, .old],
            context: &Context.buffer)
        player.addObserver(
            self,
            forKeyPath: "currentItem.loadedTimeRanges",
            options: [.initial, .new, .old],
            context: &Context.buffer)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(PlayerObserver.didPlayToEnd(notification:)),
            name: Notification.Name.AVPlayerItemDidPlayToEndTime,
            object: player.currentItem)
        
        removeObserver = { playerObserver in
            currentItem.removeObserver(playerObserver, forKeyPath: "status", context: &Context.item)
            player.removeObserver(playerObserver,
                                  forKeyPath: "currentItem.playbackLikelyToKeepUp",
                                  context: &Context.buffer)
            player.removeObserver(playerObserver,
                                  forKeyPath: "currentItem.playbackBufferFull",
                                  context: &Context.buffer)
            player.removeObserver(playerObserver,
                                  forKeyPath: "currentItem.loadedTimeRanges",
                                  context: &Context.buffer)
            
            player.removeObserver(playerObserver, forKeyPath: "rate", context: &Context.rate)
            
            NotificationCenter.default.removeObserver(
                playerObserver,
                name: Notification.Name.AVPlayerItemDidPlayToEndTime,
                object: currentItem)
        }
    }
    //swiftlint:enable function_body_length
    
    private struct Context {
        static var item = 0
        static var rate = 0
        static var buffer = 0
    }
    
    func didPlayToEnd(notification: NSNotification) {
        callbacks.endOfVideo?()
    }
    
    //swiftlint:disable cyclomatic_complexity
    override public func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard let change = change else { fatalError("Change should not be nil!") }
        guard let context = context else { fatalError("Added observer without context!") }
        
        switch context {
        case &Context.item:
            
            let item = object as! AVPlayerItem // swiftlint:disable:this force_cast
            
            switch item.status {
            case .unknown: callbacks.unknownState?()
                
            case .readyToPlay:
                callbacks.durationDefined?(duration: item.duration, forItem: item)
                callbacks.readyState?(item)
                
            case .failed:
                let playerItem = object as! AVPlayerItem // swiftlint:disable:this force_cast
                callbacks.failedState?(playerItem.error!)
            }
            
        case &Context.rate:
            // swiftlint:disable force_cast
            let newRate = change[NSKeyValueChangeKey.newKey] as! Float
            let oldRate = change[NSKeyValueChangeKey.oldKey] as? Float
            // swiftlint:enable force_cast
            
            if newRate != oldRate {
                callbacks.rateChanged?(newRate: newRate, oldRate: oldRate)
            }
            
        case &Context.buffer:
            guard let player = object as? AVPlayer else { fatalError("\(String(describing: object)) is not a player") }
            guard let item = player.currentItem else { return }
            
            let isReady = item.isPlaybackBufferFull || item.isPlaybackLikelyToKeepUp
            callbacks.playbackReady?(isReady)
            
            let ranges = item.loadedTimeRanges.map { $0.timeRangeValue }
            if let range = ranges.last {
                callbacks.bufferedTimeUpdated?(range.end)
            }
            
        default:
            super.observeValue(
                forKeyPath: keyPath,
                of: object,
                change: change,
                context: context)
        }

    }
    //swiftlint:enable cyclomatic_complexity
    
    deinit {
        removeObserver(self)
    }
}
