import SwiftUI
import WebKit

/// Hosts the single shared WKWebView. A view can only live in one place at a
/// time, so the web page moves between the iPad (no monitor) and the monitor.
struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        webView.removeFromSuperview()
        webView.frame = container.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(webView)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        // Only detach the web view if it is still ours (it may already have
        // moved to the other screen).
        for sub in uiView.subviews where sub is WKWebView {
            sub.removeFromSuperview()
        }
    }
}
