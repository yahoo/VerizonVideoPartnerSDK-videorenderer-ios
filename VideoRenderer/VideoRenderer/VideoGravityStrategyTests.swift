//  Copyright 2018, Oath Inc.
//  Licensed under the terms of the MIT License. See LICENSE.md file in project root for terms.

import XCTest
import AVFoundation
@testable import VideoRenderer

class VideoGravityTests: XCTestCase {
    func testVideoGravityDimensionsResize() {
        typealias Resize = VideoStreamView.ResizeOptions
        let vertical = Resize(allowVerticalBars: true, allowHorizontalBars: false, resizeAspectFill: false)
        let horizontal = Resize(allowVerticalBars: false, allowHorizontalBars: true, resizeAspectFill: false)
        let both = Resize(allowVerticalBars: true, allowHorizontalBars: true, resizeAspectFill: false)
        let none = Resize(allowVerticalBars: false, allowHorizontalBars: false, resizeAspectFill: false)
        
        let videoSize = CGSize(width: 800, height: 600)
        let landscapeSize = CGSize(width: 480, height: 320)
        let portraitSize = CGSize(width: 320, height: 480)
        
        let resize = AVLayerVideoGravityResize
        let match = AVLayerVideoGravityResizeAspect
        
        XCTAssertEqual(vertical.videoGravity(for: videoSize, in: portraitSize), resize)
        XCTAssertEqual(vertical.videoGravity(for: videoSize, in: landscapeSize), match)
        XCTAssertEqual(horizontal.videoGravity(for: videoSize, in: portraitSize), match)
        XCTAssertEqual(horizontal.videoGravity(for: videoSize, in: landscapeSize), resize)
        XCTAssertEqual(both.videoGravity(for: videoSize, in: portraitSize), match)
        XCTAssertEqual(both.videoGravity(for: videoSize, in: landscapeSize), match)
        XCTAssertEqual(none.videoGravity(for: videoSize, in: portraitSize), resize)
        XCTAssertEqual(none.videoGravity(for: videoSize, in: landscapeSize), resize)
    }
}
