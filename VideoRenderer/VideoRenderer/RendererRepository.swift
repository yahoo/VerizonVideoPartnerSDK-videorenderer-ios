//  Copyright © 2016 One by Aol : Publishers. All rights reserved.

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

open class RendererViewController: UIViewController {
    convenience init(context: [String: AnyObject] = [:]) {
        self.init(nibName: nil, bundle: nil)
    }
    
    public struct Props {
        public var content: URL
        public var rate: Float
        public var volume: Float
        public var newTime: CMTime?
        
        public init(content: URL,
                    rate: Float,
                    volume: Float,
                    newTime: CMTime?) {
            self.content = content
            self.rate = rate
            self.volume = volume
            self.newTime = newTime
        }
    }
    
    public enum Event {
        case playbackReady
        case playbackStarted
        case playbackStopped
        case playbackFinished
        case playbackFailed(Error)
        
        case durationReceived(CMTime)
        case currentTimeUpdated(CMTime)
        case loadedRangesUpdated([CMTimeRange])
    }
    
    public var props: Props?
    public var dispatch: Optional<(Event) -> ()> = nil
}

public struct Renderer {
    public typealias ViewController = RendererViewController
    public typealias Context = [String: AnyObject]
    public typealias Provider = (Context) -> ViewController

    public let descriptor: Desciptor
    public let provider: Provider
    
    public init(descriptor: Desciptor, provider: @escaping Provider) {
        self.descriptor = descriptor
        self.provider = provider
    }
}

extension Renderer {
    public struct Desciptor {
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

extension Renderer.Desciptor: Equatable {
    public static func == (left: Renderer.Desciptor, right: Renderer.Desciptor) -> Bool {
        guard left.id == right.id else { return false }
        guard left.version == right.version else { return false }
        
        return true
    }
}

extension Renderer.Desciptor: Hashable {
    public var hashValue: Int { return id.hashValue ^ version.hashValue }
}

extension Renderer {
    public final class Repository {
        public static let shared = Repository()
        
        private var renderers: [Desciptor: Provider] = [:]
        
        public var availableRenderers: [Desciptor] {
            return Array(renderers.keys)
        }
        
        public func makeViewControllerFor(descriptor: Desciptor,
                                          context: Context = [:]) -> ViewController? {
            return renderers[descriptor].map { $0(context) }
        }
        
        @discardableResult public func register(renderer: Renderer) -> Desciptor {
            renderers[renderer.descriptor] = renderer.provider
            return renderer.descriptor
        }
        
        public func remove(renderer: Renderer) {
            renderers[renderer.descriptor] = nil
        }
    }
}
