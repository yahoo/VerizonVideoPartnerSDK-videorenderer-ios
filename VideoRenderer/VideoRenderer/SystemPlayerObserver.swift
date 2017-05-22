//  Copyright © 2017 One by Aol : Publishers. All rights reserved.

import Foundation
import AVFoundation

public final class SystemPlayerObserver: NSObject {
    public enum Event {
        case didChangeRate(from: Float?, to: Float)
        case didChangeUrl(from: URL?, to: URL?)
        case didChangeItemStatus(from: AVPlayerItemStatus?, to: AVPlayerItemStatus)
        case didChangeItemDuration(from: CMTime?, to: CMTime?)
        case didFinishPlayback(withUrl: URL)
        case didChangeItemPlaybackBufferFull(from: Bool?, to: Bool)
        case didChangeItemPlaybackLikelyToKeepUp(from: Bool?, to: Bool)
        case didChangeLoadedTimeRanges(to: [CMTimeRange])
    }
    
    private var emit: Action<Event>
    private var player: AVPlayer
    public init(player: AVPlayer, emit: @escaping Action<Event>) {
        self.emit = emit
        self.player = player
        
        super.init()
        
        player.addObserver(self,
                           forKeyPath: #keyPath(AVPlayer.rate),
                           options: [.initial, .new, .old],
                           context: nil)
        player.addObserver(self,
                           forKeyPath: #keyPath(AVPlayer.currentItem),
                           options: [.initial, .new, .old],
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
            return change[NSKeyValueChangeKey.newKey] as? T
        }
        
        func newValueUnwrapped<T>() -> T {
            guard let newValue = change[NSKeyValueChangeKey.newKey] as? T else {
                fatalError("Unexpected nil in \(keyPath)! value!")
            }
            return newValue
        }
        
        func oldValue<T>() -> T? {
            return change[NSKeyValueChangeKey.oldKey] as? T
        }
        
        switch keyPath {
        case #keyPath(AVPlayer.rate):
            emit(.didChangeRate(from: oldValue(), to: newValueUnwrapped()))
        case #keyPath(AVPlayer.currentItem):
            
            let newItem = newValue() as AVPlayerItem?
            /* Process new item */ do {
                newItem?.addObserver(self,
                                     forKeyPath: #keyPath(AVPlayerItem.status),
                                     options: [.initial, .new, .old],
                                     context: nil)
                newItem?.addObserver(self,
                                     forKeyPath: #keyPath(AVPlayerItem.duration),
                                     options: [.initial, .new, .old],
                                     context: nil)
                newItem?.addObserver(self,
                                     forKeyPath: #keyPath(AVPlayerItem.isPlaybackBufferFull),
                                     options: [.initial, .new, .old],
                                     context: nil)
                newItem?.addObserver(self,
                                     forKeyPath: #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp),
                                     options: [.initial, .new, .old],
                                     context: nil)
                newItem?.addObserver(self,
                                     forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges),
                                     options: [.initial, .new],
                                     context: nil)
                if let new = newItem {
                    NotificationCenter.default.addObserver(
                        self,
                        selector: #selector(SystemPlayerObserver.didPlayToEnd(notification:)),
                        name: .AVPlayerItemDidPlayToEndTime,
                        object: new)
                }
            }
            
            let oldItem = oldValue() as AVPlayerItem?
            /* Process old item */ do {
                oldItem?.removeObserver(self,
                                        forKeyPath: #keyPath(AVPlayerItem.status))
                oldItem?.removeObserver(self,
                                        forKeyPath: #keyPath(AVPlayerItem.duration))
                oldItem?.removeObserver(self,
                                        forKeyPath: #keyPath(AVPlayerItem.isPlaybackBufferFull))
                oldItem?.removeObserver(self,
                                        forKeyPath: #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp))
                oldItem?.removeObserver(self,
                                        forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges))
                if let old = oldItem {
                    NotificationCenter.default.removeObserver(
                        self,
                        name: .AVPlayerItemDidPlayToEndTime,
                        object: old)
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
        case #keyPath(AVPlayerItem.duration):
            emit(.didChangeItemDuration(from: oldValue(), to: newValue()))
        case #keyPath(AVPlayerItem.isPlaybackBufferFull):
            emit(.didChangeItemPlaybackBufferFull(from: oldValue(), to: newValueUnwrapped()))
        case #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp):
            emit(.didChangeItemPlaybackLikelyToKeepUp(from: oldValue(),
                                                      to: newValueUnwrapped()))
        case #keyPath(AVPlayerItem.loadedTimeRanges):
            emit(.didChangeLoadedTimeRanges(to: newValueUnwrapped()))
        default:
            super.observeValue(
                forKeyPath: keyPath,
                of: object,
                change: change,
                context: context)
        }
    }
    
    deinit {
        player.currentItem?.removeObserver(self,
                                           forKeyPath: #keyPath(AVPlayerItem.status))
        player.currentItem?.removeObserver(self,
                                           forKeyPath: #keyPath(AVPlayerItem.duration))
        player.currentItem?.removeObserver(self,
                                           forKeyPath: #keyPath(AVPlayerItem.isPlaybackBufferFull))
        player.currentItem?.removeObserver(self,
                                           forKeyPath: #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp))
        player.currentItem?.removeObserver(self,
                                           forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges))
        player.removeObserver(self,
                              forKeyPath: #keyPath(AVPlayer.rate))
        player.removeObserver(self,
                              forKeyPath: #keyPath(AVPlayer.currentItem))
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem)
    }
}
