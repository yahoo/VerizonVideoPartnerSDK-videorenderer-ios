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
    
    private var observer: PlayerObserver?
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
    
    public struct Props {
        public let player: AVPlayerProps
        public let allowVerticalBars: Bool
        public let allowHorizontalBars: Bool
        
        public init(player: AVPlayerProps,
                    allowVerticalBars: Bool,
                    allowHorizontalBars: Bool)
        {
            self.player = player
            self.allowVerticalBars = allowVerticalBars
            self.allowHorizontalBars = allowHorizontalBars
        }
    }
    
    public var dispatch: Renderer.Dispatch?
    
    public var props: Renderer.Props? {
        didSet {
            guard let props = props, view.window != nil else {
                if let timeObserver = timeObserver {
                    player?.removeTimeObserver(timeObserver)
                }
                
                player?.replaceCurrentItem(with: nil)
                player = nil
                observer = nil
                pictureInPictureObserver = nil
                timeObserver = nil
                seekerController = nil
                
                return
            }
            
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

                currentPlayer = AVPlayer(url: props.content)
                
                var callbacks = PlayerObserver.Callbacks()
                weak var this = self
                
                callbacks.failedState = {
                    this?.dispatch?(.playbackFailed($0))
                }
                
                callbacks.rateChanged = { new, old in
                    guard new != old else { return }
                    if new == 0 { this?.dispatch?(.playbackStopped) }
                    else { this?.dispatch?(.playbackStarted) }
                }
                
                callbacks.durationDefined = { duration, _ in
                    this?.dispatch?(.durationReceived(duration))
                }
                
                callbacks.endOfVideo = {
                    this?.dispatch?(.playbackFinished)
                }
                
                callbacks.playbackReady = {
                    guard $0 == true else { return }
                    this?.dispatch?(.playbackReady)
                }
                
                callbacks.bufferedTimeUpdated = {
                    this?.dispatch?(.bufferedTimeUpdated($0))
                }
                
                observer = PlayerObserver(
                    callbacks: callbacks,
                    player: currentPlayer)
                player = currentPlayer
                seekerController = SeekerController(with: currentPlayer)
            }
            
            guard currentPlayer.currentItem?.status == .readyToPlay else { return }
            
//            videoView?.resizeOptions = VideoStreamView.ResizeOptions(
//                allowVerticalBars: props.allowVerticalBars,
//                allowHorizontalBars: props.allowHorizontalBars
//            )

            seekerController?.process(to: props.newTime)

            if timeObserver == nil {
                timeObserver = currentPlayer.addPeriodicTimeObserver(
                    forInterval: CMTime(seconds: 0.2, preferredTimescale: 600),
                    queue: nil,
                    using: { [weak self] time in
                        self?.dispatch?(.currentTimeUpdated(time))
                    })
            }
            
            currentPlayer.volume = props.volume
            
            if currentPlayer.rate != props.rate {
                currentPlayer.rate = props.rate
            }
            
            #if os(iOS)
                guard #available(iOS 9.0, *), isViewLoaded else { return }
                
                let pipController: AVPictureInPictureController? = {
                    if let pipController = self.pictureInPictureController as? AVPictureInPictureController {
                        return pipController
                    } else {
                        guard
                            let layer = videoView?.playerLayer,
                            let pipController = AVPictureInPictureController(playerLayer: layer) else { return nil }
                        pipController.delegate = self
                        pictureInPictureController = pipController
                        pictureInPictureObserver = PictureInPictureControllerObserver(pictureInPictureController: pipController, emit:
                            { [unowned self] in
                                guard case PictureInPictureControllerObserver.Event.didChangedPossibility(let possible) = $0 else { return }
                                self.dispatch?(.pictureInPictureIsPossible(possible))
                        })
                        return pipController
                    }
                }()
                
                if props.pictureInPictureActive && pipController?.isPictureInPictureActive == false {
                    pipController?.startPictureInPicture()
                }
                
                if !props.pictureInPictureActive && pipController?.isPictureInPictureActive == true {
                    pipController?.stopPictureInPicture()
                }
            #endif
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
