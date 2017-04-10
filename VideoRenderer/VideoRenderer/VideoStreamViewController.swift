//  Copyright © 2016 One by Aol : Publishers. All rights reserved.

import AVFoundation

class VideoStreamView: UIView {
    /// `AVPlayerLayer` class is returned as view backing layer.
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    private var playerLayer: AVPlayerLayer? {
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

public final class VideoStreamViewController: UIViewController {
    
    public static let descriptor = try! Renderer.Repository.shared.register(
        renderer: Renderer(
            descriptor:Renderer.Desciptor(
                id: "com.onemobilesdk.videorenderer.flat",
                version: "1.0"),
            provider: RendererViewController.init
        )
    )
    
    private var observer: PlayerObserver?
    private var timeObserver: Any?
    private var seekerController: SeekerController? = nil
    
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
    
    public var props: Props? {
        didSet {
            guard let props = props, view.window != nil else {
                if let timeObserver = timeObserver {
                    player?.removeTimeObserver(timeObserver)
                }
                
                player?.replaceCurrentItem(with: nil)
                player = nil
                observer = nil
                timeObserver = nil
                seekerController = nil
                
                return
            }
            
            let currentPlayer: AVPlayer
            
            if
                let player = player,
                let asset = player.currentItem?.asset as? AVURLAsset,
                props.player.url == asset.url {
                currentPlayer = player
            } else {
                if let timeObserver = timeObserver {
                    player?.removeTimeObserver(timeObserver)
                }
                timeObserver = nil

                currentPlayer = AVPlayer(url: props.player.url)
                
                observer = PlayerObserver(
                    callbacks: props.player.callbacks,
                    player: currentPlayer)
                player = currentPlayer
                seekerController = SeekerController(with: currentPlayer)
            }
            
            guard currentPlayer.currentItem?.status == .readyToPlay else { return }
            
            videoView?.resizeOptions = VideoStreamView.ResizeOptions(
                allowVerticalBars: props.allowVerticalBars,
                allowHorizontalBars: props.allowHorizontalBars
            )

            seekerController?.process(to: props.player.newTime)

            if timeObserver == nil {
                timeObserver = currentPlayer.addPeriodicTimeObserver(
                    forInterval: CMTime(seconds: 0.2, preferredTimescale: 600),
                    queue: nil,
                    using: { [weak self] time in
                        self?.props?.player.didPlayToTime(time)
                    })
            }
            
            currentPlayer.isMuted = props.player.isMuted
            
            if currentPlayer.rate == 1 && !props.player.isPlaying {
                currentPlayer.pause()
            }
            
            if currentPlayer.rate == 0 && props.player.isPlaying {
                currentPlayer.play()
            }
        }
    }
}
