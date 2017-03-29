//  Copyright © 2016 One by Aol : Publishers. All rights reserved.

import AVFoundation

public struct AVPlayerProps {
    public let url: URL
    public let isPlaying: Bool
    public let isMuted: Bool
    public let newTime: CMTime?
    public let callbacks: PlayerObserver.Callbacks
    public let didPlayToTime: Action<CMTime>
    
    public init(url: URL,
                isPlaying: Bool,
                isMuted: Bool,
                newTime: CMTime?,
                callbacks: PlayerObserver.Callbacks,
                didPlayToTime: @escaping Action<CMTime>) {
        self.url = url
        self.isPlaying = isPlaying
        self.isMuted = isMuted
        self.newTime = newTime
        self.callbacks = callbacks
        self.didPlayToTime = didPlayToTime
    }
}
