//  Copyright © 2016 One by Aol : Publishers. All rights reserved.

import AVFoundation
import AVKit

class VideoStreamView: UIView {
    /// `AVPlayerLayer` class is returned as view backing layer.
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    fileprivate var playerLayer: AVPlayerLayer? {
        return layer as? AVPlayerLayer
    }
    
    fileprivate var player: AVPlayer? {
        get { return playerLayer?.player }
        set { playerLayer?.player = newValue }
    }
    
    deinit {
        player?.currentItem?.asset.cancelLoading()
    }
    
    private var naturalSize: CGSize? {
        guard
            let item = player?.currentItem,
            item.status == .readyToPlay,
            let track = item.asset.tracks(withMediaType: AVMediaTypeVideo).first else {
                return nil
        }
        
        return track.naturalSize
    }
    
    var resizeOptions = ResizeOptions(allowVerticalBars: true, allowHorizontalBars: true) {
        didSet {
            guard let size = naturalSize else { return }
            
            playerLayer?.videoGravity =
                resizeOptions.videoGravity(for: size, in: bounds.size)
        }
    }
    
    struct ResizeOptions {
        let allowVerticalBars: Bool
        let allowHorizontalBars: Bool
        
        func videoGravity(for videoSize: CGSize, in hostSize: CGSize) -> String {
            let videoAspectRatio = videoSize.width / videoSize.height
            let hostAspectRatio = hostSize.width / hostSize.height
            
            switch (allowVerticalBars, allowHorizontalBars) {
            case (false, false): return AVLayerVideoGravityResize
            case (true, true): return AVLayerVideoGravityResizeAspect
            case (true, false): return hostAspectRatio < videoAspectRatio
                ? AVLayerVideoGravityResize
                : AVLayerVideoGravityResizeAspect
            case (false, true): return hostAspectRatio > videoAspectRatio
                ? AVLayerVideoGravityResize
                : AVLayerVideoGravityResizeAspect
            }
        }
    }
}

extension Renderer.Descriptor {
    public static let flat = try! Renderer.Descriptor(
        id: "com.onemobilesdk.videorenderer.flat",
        version: "1.0"
    )
}


public final class VideoStreamViewController: UIViewController, RendererProtocol {
    public static let renderer = Renderer(
        descriptor: .flat,
        provider: { VideoStreamViewController() }
    )
    
    private var observer: SystemPlayerObserver?
    private var pictureInPictureObserver: PictureInPictureControllerObserver?
    
    private var timeObserver: Any?
    private var seekerController: SeekerController? = nil
    private var pictureInPictureController: AnyObject?
    
    override public func loadView() {
        view = VideoStreamView()
    }
    
    private var videoView: VideoStreamView? {
        return view as? VideoStreamView
    }
    
    private var player: AVPlayer? {
        get { return videoView?.player }
        set { videoView?.player = newValue }
    }
    
    private var assets: [URL : AVAsset] = [:]
    
    public var dispatch: Renderer.Dispatch?
    
    public var props: Renderer.Props? {
        didSet {
            guard let props = props, view.window != nil else {
                if let timeObserver = timeObserver {
                    player?.removeTimeObserver(timeObserver)
                }
                timeObserver = nil
                
                if let asset = player?.currentItem?.asset {
                    let durationStatus = asset.statusOfValue(forKey: "duration", error: nil)
                    let mediaOptionsStatus = asset.statusOfValue(forKey: "availableMediaCharacteristicsWithMediaSelectionOptions", error: nil)
                    switch (durationStatus, mediaOptionsStatus) {
                    case (.loading, .loading):
                        asset.cancelLoading()
                    default: break
                    }
                }
                player?.replaceCurrentItem(with: nil)
                player = nil
                observer = nil
                pictureInPictureObserver = nil
                seekerController = nil
                
                return
            }
            
            #if os(iOS)
                if #available(iOS 9.0, *), isViewLoaded {
                    if pictureInPictureController == nil,
                        let layer = videoView?.playerLayer,
                        let pipController = AVPictureInPictureController(playerLayer: layer) {
                        pipController.delegate = self
                        pictureInPictureController = pipController
                    }
                }
            #endif
            
            let currentPlayer: AVPlayer
            
            if
                let player = player,
                let asset = player.currentItem?.asset as? AVURLAsset,
                props.content == asset.url {
                currentPlayer = player
            } else {
                if let timeObserver = timeObserver {
                    player?.removeTimeObserver(timeObserver)
                }
                timeObserver = nil
                
                if let asset = assets[props.content] {
                    currentPlayer = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                } else {
                    currentPlayer = AVPlayer(url: props.content)
                }
                
                observer = SystemPlayerObserver(player: currentPlayer) { [weak self] event in
                    switch event {
                    case .didChangeItemStatusToReadyToPlay:
                        self?.dispatch?(.playbackReady)
                    case .didChangeItemStatusToFailed(let error):
                        self?.dispatch?(.playbackFailed(error))
                    case .didChangeExternalPlaybackStatus(let status):
                        self?.dispatch?(.externalPlaybackPossible(status))
                    case .didChangeExternalPlaybackAllowance(let status):
                        self?.dispatch?(.externalPlaybackAllowance(status))
                    case .didChangeRate(let new):
                        self?.dispatch?(.didChangeRate(new))
                    case .didChangeTimebaseRate(let new):
                        self?.dispatch?(.didChangeTimebaseRate(new))
                    case .didChangeItemDuration(let new):
                        self?.dispatch?(.durationReceived(new))
                    case .didFinishPlayback:
                        self?.dispatch?(.playbackFinished)
                    case .didChangeLoadedTimeRanges(let new):
                        guard let end = new.last?.end else { return }
                        self?.dispatch?(.bufferedTimeUpdated(end))
                    case .didChangeAverageVideoBitrate(let new):
                        self?.dispatch?(.averageVideoBitrateUpdated(new))
                    case .didChangeAsset(let asset):
                        self?.assets[props.content] = asset
                    case .didReceivePlayerError(let error):
                        self?.dispatch?(.playbackFailed(error))
                    default: break
                    }
                }
                
                player = currentPlayer
                seekerController = SeekerController(with: currentPlayer)
                
                if let pictureInPictureController = pictureInPictureController {
                    pictureInPictureObserver = PictureInPictureControllerObserver(
                        pictureInPictureController: pictureInPictureController,
                        emit: { [weak self] in
                            guard case .didChangedPossibility(let possible) = $0 else { return }
                            self?.dispatch?(.pictureInPictureIsPossible(possible))
                    })
                }
                
                if let item = player?.currentItem {
                    let key = "availableMediaCharacteristicsWithMediaSelectionOptions"
                    item.asset.loadValuesAsynchronously(forKeys: [key]) { [weak self] in
                        var error: NSError? = nil
                        let status = item.asset.statusOfValue(forKey: key, error: &error)
                        guard case .loaded = status else { return }
                        for characteristic in item.asset.availableMediaCharacteristicsWithMediaSelectionOptions {
                            guard let group = item.asset.mediaSelectionGroup(
                                forMediaCharacteristic: characteristic)
                                else { return }
                            let options: [AVMediaSelectionOption] = {
                                guard characteristic == AVMediaCharacteristicLegible else { return group.options }
                                return group.options.filter(AVMediaSelectionOption.hasLanguageTag)
                            }()
                            let selectedOption = item.selectedMediaOption(in: group)
                            switch characteristic {
                            case AVMediaCharacteristicAudible:
                                self?.dispatch?(.audibleSelectionGroup(
                                    .init(
                                        selectedOption: selectedOption,
                                        options: options)))
                            case AVMediaCharacteristicLegible:
                                self?.dispatch?(.legibleSelectionGroup(
                                    .init(
                                        selectedOption: selectedOption,
                                        options: options)))
                            default: break
                            }
                        }
                    }
                }
            }
            
            currentPlayer.allowsExternalPlayback = props.allowsExternalPlayback
            
            guard currentPlayer.currentItem?.status == .readyToPlay else { return }
            
            //            videoView?.resizeOptions = VideoStreamView.ResizeOptions(
            //                allowVerticalBars: props.allowVerticalBars,
            //                allowHorizontalBars: props.allowHorizontalBars
            //            )
            
            if props.hasDuration == false,
                let item = player?.currentItem {
                if case .loaded = item.asset.statusOfValue(forKey: "duration", error: nil) {
                    dispatch?(.durationReceived(item.asset.duration))
                } else {
                    fatalError("No duration here! Bad situation!")
                }
            }
            
            seekerController?.process(to: props.currentTime)
            
            if timeObserver == nil {
                timeObserver = currentPlayer.addPeriodicTimeObserver(
                    forInterval: CMTime(seconds: 0.2, preferredTimescale: 600),
                    queue: nil,
                    using: { [weak self] time in
                        self?.seekerController?.currentTime = time
                        self?.dispatch?(.currentTimeUpdated(time))
                })
            }
            
            currentPlayer.isMuted = props.isMuted
            
            if currentPlayer.rate != props.rate {
                currentPlayer.rate = props.rate
            }
            
            #if os(iOS)
                if #available(iOS 9.0, *),
                    let pipController = pictureInPictureController as? AVPictureInPictureController {
                    
                    if props.pictureInPictureActive, !pipController.isPictureInPictureActive {
                        pipController.startPictureInPicture()
                    }
                    
                    if !props.pictureInPictureActive, pipController.isPictureInPictureActive {
                        pipController.stopPictureInPicture()
                    }
                }
            #endif
            
            func selectOption(for player: AVPlayer,
                              characteristic: String,
                              mediaSelection: Renderer.Props.MediaSelection) {
                guard let item = currentPlayer.currentItem else { return }
                guard let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) else { return }
                switch mediaSelection {
                case .on(let optionPropertyList):
                    guard let propertyList = try? PropertyListSerialization
                        .propertyList(from: optionPropertyList,
                                      options: .mutableContainers,
                                      format: nil) else { return }
                    let mediaOption = group.mediaSelectionOption(withPropertyList: propertyList)
                    guard mediaOption != item.selectedMediaOption(in: group) else { return }
                    
                    item.select(mediaOption, in: group)
                case .off:
                    item.select(nil, in: group)
                case .disabled: break
                }
            }
            
            selectOption(for: currentPlayer,
                         characteristic: AVMediaCharacteristicAudible,
                         mediaSelection: props.audible)
            selectOption(for: currentPlayer,
                         characteristic: AVMediaCharacteristicLegible,
                         mediaSelection: props.legible)
        }
    }
}

#if os(iOS)
    @available(iOS 9.0, *)
    extension VideoStreamViewController: AVPictureInPictureControllerDelegate {
        public func pictureInPictureControllerDidStopPictureInPicture(
            _ pictureInPictureController: AVPictureInPictureController) {
            dispatch?(.pictureInPictureStopped)
        }
    }
#endif


extension AVMediaSelectionOption {
    static func hasLanguageTag(option: AVMediaSelectionOption) -> Bool {
        guard let tag = option.extendedLanguageTag else { return false }
        guard tag != "und" else { return false }
        return true
    }
}
