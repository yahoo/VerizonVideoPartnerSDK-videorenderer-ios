//  Copyright © 2016 One by Aol : Publishers. All rights reserved.

import GLKit
import AVFoundation

private let sharedContext: EAGLContext = {
    return EAGLContext(api: .openGLES3) ?? EAGLContext(api: .openGLES2)
}()

extension Renderer.Descriptor {
    public static let sphere = try! Renderer.Descriptor(
        id: "com.onemobilesdk.videorenderer.360",
        version: "1.0"
    )
}

public class SphereVideoStreamViewController: GLKViewController, RendererProtocol {
    public static let renderer = Renderer(
        descriptor: .sphere,
        provider: { SphereVideoStreamViewController() }
    )
    
    private var player: AVPlayer?
    private var output: AVPlayerItemVideoOutput?
    private var observer: SystemPlayerObserver?
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
    
    public var dispatch: Renderer.Dispatch?
    public var props: Renderer.Props? {
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
                props.content == asset.url
            {
                currentPlayer = player
            } else {
                if let timeObserver = timeObserver {
                    player?.removeTimeObserver(timeObserver)
                }
                timeObserver = nil
                
                currentPlayer = AVPlayer(url: props.content)
                
                observer = SystemPlayerObserver(player: currentPlayer) { [weak self] event in
                    switch event {
                    case .didChangeItemStatusToFailed(let error):
                        let error: Error = {
                            guard let error = error else {
                                struct SystemPlayerFailed: Swift.Error { }
                                return SystemPlayerFailed() as NSError
                            }
                            return error
                        }()
                        self?.dispatch?(.playbackFailed(error))
                    case .didChangeTimebaseRate(let new):
                        if new == 0 { self?.dispatch?(.playbackStopped) }
                        else { self?.dispatch?(.playbackStarted) }
                    case .didChangeItemDuration(let new):
                        self?.dispatch?(.durationReceived(new))
                    case .didFinishPlayback:
                        self?.dispatch?(.playbackFinished)
                    case .didChangeLoadedTimeRanges(let new):
                        guard let end = new.last?.end else { return }
                        self?.dispatch?(.bufferedTimeUpdated(end))
                    default: break
                    }
                }
                
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
            
            sphereview?.setNeedsDisplay()
        }
    }
}
