//  Copyright © 2017 One by Aol : Publishers. All rights reserved.

import Foundation
import AVFoundation

public final class SystemPlayerObserver: NSObject {
    public enum Event {
        case didChangeTimebaseRate(to: Float)
        case didChangeRate(to: Float)
        case didChangeUrl(from: URL?, to: URL?)
        case didChangeItemStatus(from: AVPlayerItemStatus?, to: AVPlayerItemStatus)
        case didFinishPlayback(withUrl: URL)
        case didChangeLoadedTimeRanges(to: [CMTimeRange])
        case didChangeAverageVideoBitrate(to: Double)
        case didChangeItemDuration(to: CMTime)
        case didChangeAsset(AVAsset)
    }
    
    private var emit: Action<Event>
    private var player: AVPlayer
    private let center = NotificationCenter.default
    
    private var accessLogToken = nil as Any?
    private var timebaseRangeToken = nil as Any?
    public init(player: AVPlayer, emit: @escaping Action<Event>) {
        self.emit = emit
        self.player = player
        super.init()
        
        player.addObserver(self,
                           forKeyPath: #keyPath(AVPlayer.currentItem),
                           options: [.initial, .new, .old],
                           context: nil)
        
        player.addObserver(self,
                           forKeyPath: #keyPath(AVPlayer.rate),
                           options: [.initial, .new],
                           context: nil)
    }
    
    func didPlayToEnd(notification: NSNotification) {
        guard let item = notification.object as? AVPlayerItem else {
            return
        }
        guard let urlAsset = item.asset as? AVURLAsset else {
            fatalError("Asset is not AVURLAsset!")
        }
        
        emit(.didFinishPlayback(withUrl: urlAsset.url))
    }
    
    override public func observeValue(forKeyPath keyPath: String?,
                                      of object: Any?,
                                      change: [NSKeyValueChangeKey : Any]?,
                                      context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else { fatalError("Unexpected nil keypath!") }
        guard let change = change else { fatalError("Change should not be nil!") }
        
        func newValue<T>() -> T? {
            let change = change[NSKeyValueChangeKey.newKey]
            guard (change as? NSNull) == nil else { return nil }
            return change as? T
        }
        
        func newValueUnwrapped<T>() -> T {
            guard let newValue: T = newValue() else {
                fatalError("Unexpected nil in \(keyPath)! value!")
            }
            return newValue
        }
        
        func oldValue<T>() -> T? {
            return change[NSKeyValueChangeKey.oldKey] as? T
        }
        
        switch keyPath {
            
        case #keyPath(AVPlayer.rate):
            guard let newItem = newValue() as Float? else { return }
            emit(.didChangeRate(to: newItem))
            
        case #keyPath(AVPlayer.currentItem):
            
            let oldItem = oldValue() as AVPlayerItem?
            /* Process old item */ do {
                oldItem?.asset.removeObserver(self,
                                              forKeyPath: #keyPath(AVAsset.duration))
                oldItem?.removeObserver(self,
                                        forKeyPath: #keyPath(AVPlayerItem.status))
                oldItem?.removeObserver(self,
                                        forKeyPath: #keyPath(AVPlayerItem.asset))
                oldItem?.removeObserver(self,
                                        forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges))
                oldItem?.removeObserver(self,
                                        forKeyPath: #keyPath(AVPlayerItem.timebase))
                if let old = oldItem {
                    center.removeObserver(self,
                                          name: .AVPlayerItemDidPlayToEndTime,
                                          object: old)
                    if let token = accessLogToken {
                        center.removeObserver(token,
                                              name: .AVPlayerItemNewAccessLogEntry,
                                              object: old)
                    }
                }
            }
            
            let newItem = newValue() as AVPlayerItem?
            /* Process new item */ do {
                newItem?.addObserver(self,
                                     forKeyPath: #keyPath(AVPlayerItem.status),
                                     options: [.initial, .new, .old],
                                     context: nil)
                newItem?.addObserver(self,
                                     forKeyPath: #keyPath(AVPlayerItem.asset),
                                     options: [.initial, .new, .old],
                                     context: nil)
                newItem?.addObserver(self,
                                     forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges),
                                     options: [.initial, .new],
                                     context: nil)
                newItem?.addObserver(self,
                                     forKeyPath: #keyPath(AVPlayerItem.timebase),
                                     options: [.initial, .new],
                                     context: nil)
                
                if let new = newItem {
                    if case .unknown = new.asset.statusOfValue(forKey: "duration", error: nil) {
                        new.asset.loadValuesAsynchronously(forKeys: ["duration"], completionHandler: nil)
                    }
                    
                    center.addObserver(
                        self,
                        selector: #selector(SystemPlayerObserver.didPlayToEnd),
                        name: .AVPlayerItemDidPlayToEndTime,
                        object: new)
                    accessLogToken = center.addObserver(
                        forName: .AVPlayerItemNewAccessLogEntry,
                        object: nil,
                        queue: nil) { [weak self] notification in
                            guard let item = notification.object as? AVPlayerItem
                                else { return }
                            guard let log = item.accessLog() else { return }
                            guard #available(iOS 10.0, tvOS 10.0, *) else { return }
                            
                            for event in log.events {
                                self?.emit(.didChangeAverageVideoBitrate(to: event.averageVideoBitrate))
                            }
                    }
                }
            }
            
            let oldUrl: URL? = {
                guard let oldItem = oldItem else { return nil }
                guard let asset = oldItem.asset as? AVURLAsset else {
                    fatalError("Asset is not AVURLAsset!")
                }
                return asset.url
            }()
            
            let newUrl: URL? = {
                guard let newItem = newItem else { return nil }
                guard let asset = newItem.asset as? AVURLAsset else {
                    fatalError("Asset is not AVURLAsset!")
                }
                return asset.url
            }()
            
            emit(.didChangeUrl(from: oldUrl, to: newUrl))
            
        case #keyPath(AVPlayerItem.status):
            let oldStatus = oldValue().flatMap(AVPlayerItemStatus.init)
            guard let newStatus = newValue().flatMap(AVPlayerItemStatus.init) else {
                fatalError("Unexpected nil in AVPlayerItem.status value!")
            }
            
            emit(.didChangeItemStatus(from: oldStatus, to: newStatus))
            
        case #keyPath(AVPlayerItem.loadedTimeRanges):
            guard let timeRanges: [CMTimeRange] = newValue() else { return }
            emit(.didChangeLoadedTimeRanges(to: timeRanges))
            
        case #keyPath(AVPlayerItem.timebase):
            if let token = timebaseRangeToken {
                center.removeObserver(token)
            }
            
            guard let timebase: CMTimebase = newValue() else { return }
            
            weak var this = self
            func emitDidChangeTimebaseRate(for timebase: CMTimebase) {
                let rate = CMTimebaseGetRate(timebase)
                this?.emit(.didChangeTimebaseRate(to: Float(rate)))
            }
            emitDidChangeTimebaseRate(for: timebase)
            
            timebaseRangeToken = center.addObserver(
                forName: kCMTimebaseNotification_EffectiveRateChanged as NSNotification.Name,
                object: timebase,
                queue: nil) {  notification in
                    guard let object = notification.object else { return }
                    let timebase = object as! CMTimebase
                    emitDidChangeTimebaseRate(for: timebase)
            }
            
        case #keyPath(AVPlayerItem.asset):
            guard let new: AVAsset = newValue() else { return }
            emit(.didChangeAsset(new))
            
            let old: AVAsset? = oldValue()
            old?.removeObserver(self, forKeyPath: #keyPath(AVAsset.duration))
            new.addObserver(self,
                            forKeyPath: #keyPath(AVAsset.duration),
                            options: [.initial, .new],
                            context: nil)
            
        case #keyPath(AVAsset.duration):
            guard let object = object as? AVAsset else { return }
            guard case .loaded = object.statusOfValue(forKey: "duration", error: nil) else { return }
            guard let duration: CMTime = newValue() else { return }
            emit(.didChangeItemDuration(to: duration))
            
        default:
            super.observeValue(
                forKeyPath: keyPath,
                of: object,
                change: change,
                context: context)
        }
    }
    
    deinit {
        player.currentItem?.asset.removeObserver(self, forKeyPath: #keyPath(AVAsset.duration))
        player.currentItem?.removeObserver(self,
                                           forKeyPath: #keyPath(AVPlayerItem.status))
        player.currentItem?.removeObserver(self,
                                           forKeyPath: #keyPath(AVPlayerItem.asset))
        player.currentItem?.removeObserver(self,
                                           forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges))
        player.currentItem?.removeObserver(self,
                                           forKeyPath: #keyPath(AVPlayerItem.timebase))
        player.removeObserver(self,
                              forKeyPath: #keyPath(AVPlayer.currentItem))
        player.removeObserver(self,
                              forKeyPath: #keyPath(AVPlayer.rate))
        center.removeObserver(self,
                              name: .AVPlayerItemDidPlayToEndTime,
                              object: player.currentItem)
        if let token = accessLogToken {
            center.removeObserver(token,
                                  name: .AVPlayerItemNewAccessLogEntry,
                                  object: player.currentItem)
        }
        
        if let token = timebaseRangeToken {
            center.removeObserver(token,
                                  name: kCMTimebaseNotification_EffectiveRateChanged as NSNotification.Name,
                                  object: player.currentItem)
        }
    }
}
