//  Copyright © 2017 Oath. All rights reserved.
import Foundation

/*
 Repository responsibility is manage availability of different
 kind of renderers in the system. 
 Each renderer can be presented in a repository in a form of 
 `Descriptor` struct.
 Goal of descriptor is to represent renderer.
 Also repository can build renderer instance for given description.
 */


import CoreMedia
import AVFoundation

public protocol RendererProtocol: class {
    var viewController: UIViewController { get }
    var props: Renderer.Props? { get set }
    var dispatch: Renderer.Dispatch? { get set }
}

extension RendererProtocol where Self: UIViewController {
    public var viewController: UIViewController { return self }
}

public struct Renderer {
    public typealias Provider = () -> RendererProtocol
    

    public let descriptor: Descriptor
    public let provider: Provider
    
    public init(descriptor: Descriptor, provider: @escaping Provider) {
        self.descriptor = descriptor
        self.provider = provider
    }
}

extension Renderer {
    public struct Props {
        public typealias Option = AvailableMediaOptions.Option
        
        public var angles: (vertical: Float, horizontal: Float)
        public var content: URL
        public var rate: Float
        public var isMuted: Bool
        public var currentTime: CMTime?
        public var hasDuration: Bool
        public var pictureInPictureActive: Bool
        public var allowsExternalPlayback: Bool
        public var audible: Option?
        public var legible: Option?
        
        public init(angles: (vertical: Float, horizontal: Float),
                    content: URL,
                    rate: Float,
                    isMuted: Bool,
                    currentTime: CMTime?,
                    hasDuration: Bool,
                    pictureInPictureActive: Bool,
                    allowsExternalPlayback: Bool,
                    audible: Option?,
                    legible: Option?) {
            self.angles = angles
            self.content = content
            self.rate = rate
            self.isMuted = isMuted
            self.currentTime = currentTime
            self.hasDuration = hasDuration
            self.pictureInPictureActive = pictureInPictureActive
            self.allowsExternalPlayback = allowsExternalPlayback
            self.audible = audible
            self.legible = legible
        }
    }
}

extension Renderer {
    public typealias Dispatch = (Event) -> Void
    
    public enum Event {
        case didChangeRate(Float)
        case didChangeTimebaseRate(Float)
        case playbackFinished
        case playbackReady
        case playbackFailed(Error)
        
        case durationReceived(CMTime)
        case currentTimeUpdated(CMTime)
        case bufferedTimeUpdated(CMTime)
        case pictureInPictureStopped
        case pictureInPictureIsPossible(Bool)
        case externalPlaybackAllowance(Bool)
        case externalPlaybackPossible(Bool)
        case averageVideoBitrateUpdated(Double)
        case updateAudibleOptions(AvailableMediaOptions)
        case updateLegibleOptions(AvailableMediaOptions)
        case startDiscoveringMediaOptions
        
        public struct MediaSelectionGroup {
            public let selectedOption: AVMediaSelectionOption?
            public let options: [AVMediaSelectionOption]
        }
    }
}

extension Renderer {
    public struct Descriptor {
        /// Example: com.aol.onemobilesdk.flat
        public let id: String
        
        /// Example: 1.0.0 basically semver 2.0
        public let version: String
        
        public enum Error: Swift.Error {
            case emptyID, emptyVersion
        }
        
        /// Throw error in case of empty id or version values
        public init(id: String, version: String) throws {
            guard !id.isEmpty else { throw Error.emptyID }
            guard !version.isEmpty else { throw Error.emptyVersion }
            
            self.id = id
            self.version = version
        }
    }
}

extension Renderer.Descriptor: Equatable {
    public static func == (left: Renderer.Descriptor, right: Renderer.Descriptor) -> Bool {
        guard left.id == right.id else { return false }
        guard left.version == right.version else { return false }
        
        return true
    }
}

extension Renderer.Descriptor: Hashable {
    public var hashValue: Int { return id.hashValue ^ version.hashValue }
}

extension Renderer {
    public final class Repository {
        public static let shared = Repository()
        
        init() {
            register(renderer: VideoStreamViewController.renderer)
            // Concept of renderers is not used on tvOS yet.
            // The only supported type is flat rendering - so
            // it is the only one that should be registered for tvOS.
            #if os(iOS)
            register(renderer: SphereVideoStreamViewController.renderer)
            #endif
        }
        
        private var renderers: [Descriptor: Provider] = [:]
        
        public var availableRenderers: [Descriptor] {
            return Array(renderers.keys)
        }
        
        public func makeViewControllerFor(descriptor: Descriptor) -> RendererProtocol? {
            return renderers[descriptor].map({ $0() })
        }
        
        public func register(renderer: Renderer) {
            renderers[renderer.descriptor] = renderer.provider
        }
        
        public func remove(renderer: Renderer) {
            renderers[renderer.descriptor] = nil
        }
    }
}
