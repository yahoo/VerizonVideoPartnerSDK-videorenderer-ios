//  Copyright © 2016 One by Aol : Publishers. All rights reserved.

import Foundation
import AVFoundation
import CoreMedia

public final class SeekerController {
    public let player: AVPlayer
    
    public init(with player: AVPlayer) {
        self.player = player
    }
    
    public var currentTime: CMTime?
    private var newTime: CMTime?
    private var activeSeekingTime: CMTime?
    
    public func process(to newTime: CMTime?) {
        guard self.newTime != newTime else { return }
        guard self.currentTime != newTime else { return }
        self.newTime = newTime
        self.currentTime = newTime
        
        guard let time = newTime else { return }
        guard activeSeekingTime == nil else { return }
        activeSeekingTime = time
        player.seek(to: time,
                    toleranceBefore: CMTimeMake(0, 1),
                    toleranceAfter: CMTimeMake(1, 2)) { [weak self] _ in
                        self?.activeSeekingTime = nil
        }
    }
}
