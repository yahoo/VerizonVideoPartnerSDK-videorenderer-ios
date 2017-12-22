//  Copyright © 2017 Oath. All rights reserved.
import Foundation
import AVFoundation
import CoreMedia

public final class SeekerController {
    public let player: AVPlayer
    
    public init(with player: AVPlayer) {
        self.player = player
    }
    
    public var currentTime: CMTime?
    private var activeSeekingTime: CMTime?
    
    public func process(to newTime: CMTime?) {
        guard self.currentTime != newTime else { return }
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
