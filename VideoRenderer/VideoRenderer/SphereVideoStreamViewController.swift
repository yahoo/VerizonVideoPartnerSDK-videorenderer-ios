//  Copyright © 2016 One by Aol : Publishers. All rights reserved.

import GLKit
import AVFoundation

private let sharedContext: EAGLContext = {
    return EAGLContext(api: .openGLES3) ?? EAGLContext(api: .openGLES2)
}()

public class SphereVideoStreamViewController: GLKViewController {
    private var player: AVPlayer?
    private var output: AVPlayerItemVideoOutput?
    private var observer: PlayerObserver?
    private var timeObserver: Any?
    private var seekerController: SeekerController? = nil
    
    var sphereview: SphereView? {
        return view as? SphereView
    }
    
    override public func loadView() {
        view = SphereView()
        
        EAGLContext.setCurrent(sharedContext)
        sphereview?.context = sharedContext
        sphereview?.buildSphere()
    }
    
    deinit {
        if EAGLContext.current() == sphereview?.context {
            EAGLContext.setCurrent(nil)
        }
    }
    
    func update() { // This method is called by GL subsystem when paused is false
        guard player?.currentItem?.status == .readyToPlay else { return }
        
        guard let currentTime = player?.currentTime() else { return }
        
        guard let pixelBuffer = output?.copyPixelBuffer(
            forItemTime: currentTime,
            itemTimeForDisplay: nil) else { return }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            preconditionFailure("Pixel buffer base address is nil!")
        }
        
        sphereview?.updateTexture(
            size: CGSize(width: width, height: height),
            imageData: baseAddress)
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
    }
    
    public struct Props {
        public let player: AVPlayerProps
        public let angles: (horizontal: CGFloat, vertical: CGFloat)
        
        public init(player: AVPlayerProps,
                    angles: (horizontal: CGFloat, vertical: CGFloat))
        {
            self.player = player
            self.angles = angles
        }
    }
    
    public var props: Props? {
        didSet {
            guard let props = props, view.window != nil else {
                if let timeObserver = timeObserver {
                    player?.removeTimeObserver(timeObserver)
                }
                
                player?.replaceCurrentItem(with: nil)
                output = nil
                observer = nil
                timeObserver = nil
                seekerController = nil
                
                return
            }
            
            let currentPlayer: AVPlayer
            
            if
                let player = player,
                let asset = player.currentItem?.asset as? AVURLAsset,
                props.player.url == asset.url
            {
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
                
                let pixelBufferAttributes = [
                    kCVPixelBufferPixelFormatTypeKey as String :
                        NSNumber(value: kCVPixelFormatType_32BGRA),
                    kCVPixelBufferWidthKey as String : 1024,
                    kCVPixelBufferHeightKey as String : 512
                ]
                
                let videoOutput =
                    AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBufferAttributes)
                currentPlayer.currentItem?.add(videoOutput)
                output = videoOutput
            }
        
            sphereview?.camera.pitch = .init(props.angles.vertical)
            sphereview?.camera.yaw = .init(props.angles.horizontal)
        
            guard currentPlayer.currentItem?.status == .readyToPlay else { return }
            
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
            
            if currentPlayer.rate == 1, !props.player.isPlaying {
                currentPlayer.pause()
            }
            
            if currentPlayer.rate == 0, props.player.isPlaying {
                currentPlayer.play()
            }
            
            sphereview?.setNeedsDisplay()
        }
    }
}
