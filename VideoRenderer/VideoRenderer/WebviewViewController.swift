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
    private var isPlaying = false
    private var isVPAIDInitiated = false
    
    public var props: Renderer.Props? {
        didSet {
            guard let props = props else { webview?.stopLoading(); return }
            if !isLoaded && webview?.isLoading == false {
                isLoaded = true
                guard let adParameters = props.adParameters else { return }
                webview?.evaluateJavaScript("initAd('\(props.content)', \(adParameters))")
            }
            
            guard isLoaded && isVPAIDInitiated && webview?.isLoading == false else { return }
            
            webview?.evaluateJavaScript(props.isMuted ? "mute()" : "unmute()")
            
            if props.isFinished { webview?.evaluateJavaScript("finishPlayback()") }

            if props.rate == 1.0 && !isPlaying {
                webview?.evaluateJavaScript("resumeAd()") { [weak self] (object, error) in
                    if let error = error { print(error) } else { self?.isPlaying = true }
                }
            }

            if props.rate == 0.0 && isPlaying {
                webview?.evaluateJavaScript("pauseAd()") { [weak self] (object, error) in
                    if let error = error { print(error) } else { self?.isPlaying = false }
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
            case .AdLoaded:
                self?.isVPAIDInitiated = true
                self?.dispatch?(.playbackReady)
            case .AdDurationChanged(let time):
                self?.dispatch?(.durationReceived(time))
            case .AdCurrentTimeChanged(let time):
                self?.dispatch?(.currentTimeUpdated(time))
            case .AdPaused:
                self?.dispatch?(.didChangeRate(0.0))
            case .AdResumed:
                self?.dispatch?(.didChangeRate(1.0))
            case .AdStarted:
                return
            case .AdSkipped:
                self?.dispatch?(.playbackFinished)
            case .AdStopped:
                self?.dispatch?(.playbackFinished)
            case .AdVideoFirstQuartile:
                return
            case .AdVideoMidPoint:
                return
            case .AdVideoThirdQuartile:
                return
            case .AdVideoComplete:
                return
            case .AdError(let error):
                self?.dispatch?(.playbackFailed(NSError(domain: error, code: 0)))
            case .AdSizeChange:
                return
            case .AdClickThru:
                return
            case .AdNotSupported:
                self?.dispatch?(.playbackFailed(NSError(domain: "Unsupported VPAID version", code: 1))) //should dispatch that vpaid version is not supported
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
        case AdDurationChanged(CMTime)
        case AdCurrentTimeChanged(CMTime)
        case AdLoaded
        case AdNotSupported
        case AdStarted
        case AdStopped
        case AdSkipped
        case AdPaused
        case AdResumed
        case AdSizeChange
        case AdVideoFirstQuartile
        case AdVideoMidPoint
        case AdVideoThirdQuartile
        case AdVideoComplete
        case AdClickThru
        case AdError(String)
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
        print(result.name)
        switch result.name {
        case "AdDurationChanged":
            guard let value = result.value, let time = Double(value) else { return }
            dispatcher(.AdDurationChanged(CMTime(seconds: time, preferredTimescale: 600)))
        case "AdCurrentTimeChanged":
            guard let value = result.value, let time = Double(value) else { return }
            dispatcher(.AdCurrentTimeChanged(CMTime(seconds: time, preferredTimescale: 600)))
        case "AdLoaded":
            dispatcher(.AdLoaded)
        case "AdStarted":
            dispatcher(.AdStarted)
        case "AdStopped":
            dispatcher(.AdStopped)
        case "AdSkipped":
            dispatcher(.AdSkipped)
        case "AdPaused":
            dispatcher(.AdPaused)
        case "AdVideoFirstQuartile":
            dispatcher(.AdVideoFirstQuartile)
        case "AdVideoMidPoint":
            dispatcher(.AdVideoMidPoint)
        case "AdVideoThirdQuartile":
            dispatcher(.AdVideoThirdQuartile)
        case "AdVideoComplete":
            dispatcher(.AdVideoComplete)
        case "AdError":
            guard let value = result.value else { return }
            dispatcher(.AdError(value))
        case "AdSizeChange":
            dispatcher(.AdSizeChange)
        case "AdClickThru":
            dispatcher(.AdClickThru)
        case "AdNotSupported":
            dispatcher(.AdNotSupported)
        default: return
        }
    }
}

struct WebKitMessage: Codable {
    let name: String
    let value: String?
}
