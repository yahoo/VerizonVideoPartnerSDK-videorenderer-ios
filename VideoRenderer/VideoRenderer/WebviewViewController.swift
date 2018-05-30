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
                let js = "updateVideoTagWithSrc('\(props.content.absoluteString)')"
                webview?.evaluateJavaScript(js) { (object, error) in
                    if let error = error {
                        print(error)
                    }
                }
            }
            if webview?.isLoading == false {
                let js = props.isMuted ? "mute()" : "unmute()"
                webview?.evaluateJavaScript(js) { (object, error) in
                    if let error = error {
                        print(error)
                    }
                }
            }
            if webview?.isLoading == false && props.isFinished {
                let js = "finishPlayback()"
                webview?.evaluateJavaScript(js) { (object, error) in
                    if let error = error {
                        print(error)
                    }
                }
            }
            
            if webview?.isLoading == false && props.rate == 1.0 {
                webview?.evaluateJavaScript("playVideo()") { (object, error) in
                    if let error = error {
                        print(error)
                    }
                }
            }
            
            if webview?.isLoading == false && props.rate == 0.0 {
                webview?.evaluateJavaScript("pauseVideo()") { (object, error) in
                    if let error = error {
                        print(error)
                    }
                }
            }
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
            case .currentTime(let currentTime):
                self?.dispatch?(.currentTimeUpdated(currentTime))
            case .duration(let duration):
                self?.dispatch?(.durationReceived(duration))
            case .playbackFinished:
                self?.dispatch?(.playbackFinished)
            case .playbackReady:
                self?.dispatch?(.playbackReady)
            case .playbackError(let error):
                let error = NSError(domain: "webViewPlaybackError", code: Int(error))
                self?.dispatch?(.playbackFailed(error))
            case .playbackRateChanged(let rate):
                self?.dispatch?(.didChangeRate(Float(rate)))
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
        case currentTime(CMTime)
        case duration(CMTime)
        case playbackError(Double)
        case playbackFinished
        case playbackReady
        case playbackRateChanged(Double)
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
        case "durationChanged":
            guard let value = result.value else { return }
            dispatcher(.duration(CMTime(seconds: value, preferredTimescale: 600)))
        case "currentTimeChanged":
            guard let value = result.value else { return }
            dispatcher(.currentTime(CMTime(seconds: value, preferredTimescale: 600)))
        case "playbackReady":
            dispatcher(.playbackReady)
        case "playbackFinished":
            dispatcher(.playbackFinished)
        case "playbackError":
            guard let value = result.value else { return }
            dispatcher(.playbackError(value))
        case "playbackRate":
            guard let value = result.value else { return }
            dispatcher(.playbackRateChanged(value))
        default: return
        }
    }
}
