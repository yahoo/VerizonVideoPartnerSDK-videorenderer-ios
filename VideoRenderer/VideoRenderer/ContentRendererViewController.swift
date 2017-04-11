//  Copyright © 2016 One by Aol : Publishers. All rights reserved.

import Foundation
import AVFoundation

public final class ContentRendererViewController: UIViewController {
    
    public enum Props {
        case sphere(SphereVideoStreamViewController.Props)
        case flat(Renderer.Props)
    }
    
    public var props: Props? {
        didSet {
            guard let props = props else {
                (currentRenderer as? SphereVideoStreamViewController)?.props = nil
                (currentRenderer as? VideoStreamViewController)?.props = nil
                return
            }
            
            switch props {
            case let .sphere(props):
                if let renderer = currentRenderer as? SphereVideoStreamViewController {
                    renderer.props = props
                } else {
                    let renderer = SphereVideoStreamViewController()
                    currentRenderer = renderer
                    
                    renderer.props = props
                }
                
            case let .flat(props):
                if let renderer = currentRenderer as? VideoStreamViewController {
                    renderer.props = props
                } else {
                    let renderer = VideoStreamViewController()
                    currentRenderer = renderer
                    
                    renderer.props = props
                }
            }
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        currentRenderer?.beginAppearanceTransition(false, animated: animated)
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        currentRenderer?.endAppearanceTransition()
    }
    
    private var currentRenderer: UIViewController? {
        willSet {
            guard let renderer = currentRenderer else { return }
            
            (renderer as? SphereVideoStreamViewController)?.props = nil
            (renderer as? VideoStreamViewController)?.props = nil
            
            renderer.willMove(toParentViewController: nil)
            renderer.beginAppearanceTransition(false, animated: false)
            renderer.view.removeFromSuperview()
            renderer.endAppearanceTransition()
            renderer.removeFromParentViewController()
        }
        
        didSet {
            guard let renderer = currentRenderer else { return }
            
            addChildViewController(renderer)
            renderer.view.frame = view.bounds
            renderer.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            renderer.beginAppearanceTransition(true, animated: false)
            view.addSubview(renderer.view)
            renderer.endAppearanceTransition()
            renderer.didMove(toParentViewController: self)
        }
    }
    
    //swiftlint:disable variable_name
    override public var shouldAutomaticallyForwardAppearanceMethods: Bool {
        return false
    }
    //swiftlint:enable variable_name
}
