//  Copyright © 2016 One by Aol : Publishers. All rights reserved.

import XCTest
import Nimble
import AVFoundation
@testable import OneMobileSDK

class VideoGravityTests: XCTestCase {
    func testVideoGravityDimensionsResize() {
        typealias Resize = VideoStreamView.ResizeOptions
        let vertical = Resize(allowVerticalBars: true, allowHorizontalBars: false)
        let horizontal = Resize(allowVerticalBars: false, allowHorizontalBars: true)
        let both = Resize(allowVerticalBars: true, allowHorizontalBars: true)
        let none = Resize(allowVerticalBars: false, allowHorizontalBars: false)
        
        let videoSize = CGSize(width: 800, height: 600)
        let landscapeSize = CGSize(width: 480, height: 320)
        let portraitSize = CGSize(width: 320, height: 480)
        
        let resize = AVLayerVideoGravityResize
        let match = AVLayerVideoGravityResizeAspect
        
        expect(vertical.videoGravity(for: videoSize, in: portraitSize)) == resize
        expect(vertical.videoGravity(for: videoSize, in: landscapeSize)) == match
        expect(horizontal.videoGravity(for: videoSize, in: portraitSize)) == match
        expect(horizontal.videoGravity(for: videoSize, in: landscapeSize)) == resize
        expect(both.videoGravity(for: videoSize, in: portraitSize)) == match
        expect(both.videoGravity(for: videoSize, in: landscapeSize)) == match
        expect(none.videoGravity(for: videoSize, in: portraitSize)) == resize
        expect(none.videoGravity(for: videoSize, in: landscapeSize)) == resize
    }
}
