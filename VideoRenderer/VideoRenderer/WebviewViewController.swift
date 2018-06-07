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
                webview?.evaluateJavaScript("initAd()") { [weak self] (object, error) in
                    guard let object = object as? String else { self?.isLoaded = true; return }
                    self?.dispatch?(.playbackFailed(NSError(domain: object, code: 0, userInfo: nil)))
                }
                guard isLoaded else { return }
                webview?.evaluateJavaScript("subscribe()") { _ in }
                webview?.evaluateJavaScript("startAd()") { _ in }
            }
            if isLoaded && webview?.isLoading == false {
                let js = props.isMuted ? "mute()" : "unmute()"
                webview?.evaluateJavaScript(js) { (object, error) in
                    if let error = error {
                        print(error)
                    }
                }
            }
            if isLoaded && webview?.isLoading == false && props.isFinished {
                webview?.evaluateJavaScript("finishPlayback()") { (object, error) in
                    if let error = error {
                        print(error)
                    }
                }
            }

            if isLoaded && webview?.isLoading == false && props.rate == 1.0 {
                webview?.evaluateJavaScript("resumeAd()") { (object, error) in
                    if let error = error {
                        print(error)
                    }
                }
            }

            if isLoaded && webview?.isLoading == false && props.rate == 0.0 {
                webview?.evaluateJavaScript("pauseAd()") { (object, error) in
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
            case .AdLoaded:
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
            case .AdError:
                self?.dispatch?(.playbackFailed(NSError()))
            case .AdSizeChange:
                return
            case .AdClickThru:
                return
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
        default: return
        }
    }
}

struct WebKitMessage: Codable {
    let name: String
    let value: String?
}
