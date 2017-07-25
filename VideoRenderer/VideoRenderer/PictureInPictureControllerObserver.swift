//  Copyright © 2017 One by Aol : Publishers. All rights reserved.

import Foundation
import AVKit

public final class PictureInPictureControllerObserver: NSObject {
    
    public enum Event {
        case didChangedPossibility(to: Bool)
    }

    private let keyPathPiPPossible: String? = {
        #if os(iOS)
            return #keyPath(AVPictureInPictureController.pictureInPicturePossible)
        #else
            return nil
        #endif
    }()
    
    private let emit: Action<Event>
    private let pictureInPictureController: AnyObject
    
    public init(pictureInPictureController: AnyObject, emit: @escaping Action<Event>) {
        self.emit = emit
        self.pictureInPictureController = pictureInPictureController
        
        super.init()
        
        guard  let keyPathPiPPossible = keyPathPiPPossible else { return }
        pictureInPictureController.addObserver(self,
                                               forKeyPath: keyPathPiPPossible,
                                               options: [.initial, .new],
                                               context: nil)
    }
    
    override public func observeValue(forKeyPath keyPath: String?,
                                      of object: Any?,
                                      change: [NSKeyValueChangeKey : Any]?,
                                      context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath else { fatalError("Unexpected nil keypath!") }
        guard let change = change else { fatalError("Change should not be nil!") }
        
        guard keyPath == keyPathPiPPossible else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        guard let newKey = change[.newKey] as? NSNumber else { return }        
        emit(.didChangedPossibility(to: newKey.boolValue))
    }
    
    deinit {
        guard  let keyPathPiPPossible = keyPathPiPPossible else { return }
        pictureInPictureController.removeObserver(self, forKeyPath: keyPathPiPPossible)
    }
}
