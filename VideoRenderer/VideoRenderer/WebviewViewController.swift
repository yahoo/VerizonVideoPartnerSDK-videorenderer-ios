//  Copyright 2018, Oath Inc.
//  Licensed under the terms of the MIT License. See LICENSE.md file in project root for terms.

import Foundation
import WebKit
import CoreMedia

extension Renderer.Descriptor {
    public static let webview = try! Renderer.Descriptor(
        id: "com.onemobilesdk.videorenderer.webview",
        version: "1.0")
}

public final class WebviewViewController: UIViewController, RendererProtocol {
    public static let renderer = Renderer(
        descriptor: .webview,
        provider: { WebviewViewController() })
    
    public var dispatch: Renderer.Dispatch?
    
    private var webview: WKWebView? {
        return view as? WKWebView
    }
    
    private var isLoaded = false
    
    public var props: Renderer.Props? {
        didSet {
            guard let props = props else { webview?.stopLoading(); return }
            if !isLoaded && webview?.isLoading == false {
                isLoaded = true
                let js = "initAd()"
                webview?.evaluateJavaScript(js) { (object, error) in
                    if let error = error {
                        print(error)
                    }
                    if let object = object {
                        print(object)
                    }
                }
            }
//            if !isLoaded && webview?.isLoading == false {
//                isLoaded = true
//                let js = "updateVideoTagWithSrc('\(props.content.absoluteString)')"
//                webview?.evaluateJavaScript(js) { (object, error) in
//                    if let error = error {
//                        print(error)
//                    }
//                }
//            }
//            if webview?.isLoading == false {
//                let js = props.isMuted ? "mute()" : "unmute()"
//                webview?.evaluateJavaScript(js) { (object, error) in
//                    if let error = error {
//                        print(error)
//                    }
//                }
//            }
//            if webview?.isLoading == false && props.isFinished {
//                let js = "finishPlayback()"
//                webview?.evaluateJavaScript(js) { (object, error) in
//                    if let error = error {
//                        print(error)
//                    }
//                }
//            }
//
//            if webview?.isLoading == false && props.rate == 1.0 {
//                webview?.evaluateJavaScript("playVideo()") { (object, error) in
//                    if let error = error {
//                        print(error)
//                    }
//                }
//            }
//
//            if webview?.isLoading == false && props.rate == 0.0 {
//                webview?.evaluateJavaScript("pauseVideo()") { (object, error) in
//                    if let error = error {
//                        print(error)
//                    }
//                }
//            }
        }
    }
    
    public override func loadView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = false
        config.allowsPictureInPictureMediaPlayback = false
        
        let userController = WKUserContentController()
        userController.add(VideoTagMessageHandler(dispatcher: { [weak self] event in
            switch event {
            case .AdLoaded:
                self?.dispatch?(.playbackReady)
            case .AdPaused:
                return
            case .AdStarted:
                return
            case .AdSkipped:
                return
            case .AdStopped:
                return
            case .AdRemainingTimeChange(let currentTime):
                self?.dispatch?(.currentTimeUpdated(currentTime))
            case .AdDurationChange(let duration):
                self?.dispatch?(.durationReceived(duration))
            case .AdVideoFirstQuartile:
                return
            case .AdVideoMidPoint:
                return
            case .AdVideoThirdQuartile:
                return
            case .AdVideoComplete:
                self?.dispatch?(.playbackFinished)
            case .AdError:
                self?.dispatch?(.playbackFailed(NSError()))
            default: return
            }
        }), name: "observer")
        config.userContentController = userController
        
        let webview = WKWebView(frame: .zero, configuration: config)
        webview.backgroundColor = .black
        webview.scrollView.backgroundColor = .black
        defer { view = webview }
        
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "video-tag", withExtension: "html") else { return }
        guard let html = try? String(contentsOf: url) else { return }
        webview.loadHTMLString(html, baseURL: bundle.resourceURL)
    }
}

final class VideoTagMessageHandler: NSObject, WKScriptMessageHandler {
    enum Event {
        case AdRemainingTimeChange(CMTime)
        case AdDurationChange(CMTime)
        case AdLoaded
        case AdStarted
        case AdStopped
        case AdSkipped
        case AdPaused
        case AdSizeChange
        case AdVideoFirstQuartile
        case AdVideoMidPoint
        case AdVideoThirdQuartile
        case AdVideoComplete
        case AdClickThru
        case AdError
    }
    
    let dispatcher: (Event) -> ()
    
    init(dispatcher: @escaping (Event) -> ()) {
        self.dispatcher = dispatcher
        super.init()
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "observer" else { return }
        guard let body = message.body as? String else { return }
        guard let data = body.data(using: .utf8) else { return }
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(WebKitMessage.self, from: data) else { return }
        switch result.name {
        case "AdDurationChange":
            return
        case "AdRemainingTimeChange":
            return
        case "AdLoaded":
            return
        case "AdStarted":
            return
        case "AdStopped":
            return
        case "AdSkipped":
            return
        case "AdPaused":
            return
        case "AdVideoFirstQuartile":
            return
        case "AdVideoMidPoint":
            return
        case "AdVideoThirdQuartile":
            return
        case "AdVideoComplete":
            return
        case "AdError":
            return
        case "AdSizeChange":
            return
        default: return
        }
    }
}
