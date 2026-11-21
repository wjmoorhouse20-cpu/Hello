import SwiftUI
import WebKit
import Combine

/// Owns the web view and everything the iPad remote can do to it.
@MainActor
final class BrowserController: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    static let shared = BrowserController()

    let webView: WKWebView

    // Page state
    @Published var addressText = ""
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false
    @Published private(set) var progress: Double = 0

    // Monitor state
    @Published private(set) var isExternalConnected = false
    @Published private(set) var externalResolution: CGSize = .zero
    @Published var viewportSize: CGSize = .zero

    // Pointer
    @Published private(set) var cursor = CGPoint(x: 300, y: 200)
    @Published private(set) var cursorActive = true
    @Published private(set) var clickPulse = 0
    @Published var showCursor = true
    @Published var sensitivity: Double = 1.5

    // Display options
    @Published var zoom: Double = 1.0 {
        didSet { webView.pageZoom = CGFloat(zoom) }
    }
    @Published private(set) var videoFillOn = false
    @Published var statusMessage: String?

    private var hideCursorTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true          // keep video on the monitor, not a native iPad player
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true // site "full screen" buttons fill the monitor
        config.defaultWebpagePreferences.preferredContentMode = .desktop

        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1280, height: 720), configuration: config)
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.allowsBackForwardNavigationGestures = true

        webView.publisher(for: \.url).map { $0?.absoluteString ?? "" }.assign(to: &$addressText)
        webView.publisher(for: \.canGoBack).assign(to: &$canGoBack)
        webView.publisher(for: \.canGoForward).assign(to: &$canGoForward)
        webView.publisher(for: \.isLoading).assign(to: &$isLoading)
        webView.publisher(for: \.estimatedProgress).assign(to: &$progress)

        load("https://www.youtube.com")
    }

    // MARK: - Navigation

    func load(_ input: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let url: URL?
        let lower = text.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            url = URL(string: text)
        } else if text.contains(" ") || !text.contains(".") {
            var comps = URLComponents(string: "https://www.google.com/search")!
            comps.queryItems = [URLQueryItem(name: "q", value: text)]
            url = comps.url
        } else {
            url = URL(string: "https://" + text)
        }
        if let url { webView.load(URLRequest(url: url)) }
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reloadOrStop() { isLoading ? webView.stopLoading() : webView.reload() }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        videoFillOn = false
    }

    /// Open "new window" links in the same view instead of dropping them.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    // MARK: - Monitor connect / disconnect

    func externalDisplayConnected(resolution: CGSize) {
        externalResolution = resolution
        isExternalConnected = true
        UIApplication.shared.isIdleTimerDisabled = true   // don't let the iPad sleep mid-movie
        cursor = CGPoint(x: 300, y: 200)
        wakeCursor()
    }

    func externalDisplayDisconnected() {
        isExternalConnected = false
        externalResolution = .zero
        viewportSize = .zero
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Pointer

    private var pointerArea: CGSize {
        viewportSize == .zero ? webView.bounds.size : viewportSize
    }

    func moveCursor(dx: CGFloat, dy: CGFloat, speed: CGFloat) {
        let acceleration = 1 + min(speed / 800, 2.5)
        let k = CGFloat(sensitivity) * acceleration
        let area = pointerArea
        cursor = CGPoint(
            x: min(max(cursor.x + dx * k, 0), max(area.width - 1, 0)),
            y: min(max(cursor.y + dy * k, 0), max(area.height - 1, 0))
        )
        wakeCursor()
    }

    private func wakeCursor() {
        cursorActive = true
        hideCursorTask?.cancel()
        hideCursorTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.cursorActive = false
        }
    }

    /// Cursor position as a fraction of the visible page (0...1). JavaScript
    /// converts this to CSS pixels, so it stays correct at any zoom level.
    private var cursorFraction: (Double, Double) {
        let area = pointerArea
        guard area.width > 0, area.height > 0 else { return (0, 0) }
        return (Double(cursor.x / area.width), Double(cursor.y / area.height))
    }

    func click() {
        clickPulse += 1
        wakeCursor()
        let (fx, fy) = cursorFraction
        run(JS.click, ["fx": fx, "fy": fy])
    }

    func scroll(dx: CGFloat, dy: CGFloat) {
        let area = pointerArea
        guard area.width > 0, area.height > 0 else { return }
        let (fx, fy) = cursorFraction
        run(JS.scroll, [
            "fx": fx, "fy": fy,
            "dfx": Double(dx / area.width), "dfy": Double(dy / area.height)
        ])
    }

    func page(down: Bool) {
        let area = pointerArea
        scroll(dx: 0, dy: (down ? 1 : -1) * area.height * 0.8)
    }

    // MARK: - Keyboard

    func type(_ text: String) {
        guard !text.isEmpty else { return }
        run(JS.typeText, ["text": text]) { [weak self] result in
            if (result as? Bool) != true {
                self?.flash("Click a text box on the monitor first")
            }
        }
    }

    func pressBackspace() { run(JS.backspace) }
    func pressEnter() { run(JS.enter) }

    // MARK: - Video fill

    /// Stretches the main video on the page to cover the whole monitor
    /// (works even on sites without a full-screen button).
    func toggleVideoFill() {
        run(JS.toggleVideoFill) { [weak self] result in
            guard let self else { return }
            if let on = result as? Bool {
                self.videoFillOn = on
            } else {
                self.videoFillOn = false
                self.flash("No video found on this page")
            }
        }
    }

    // MARK: - Helpers

    func flash(_ message: String) {
        statusMessage = message
        statusTask?.cancel()
        statusTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.statusMessage = nil
        }
    }

    private func run(_ body: String,
                     _ args: [String: Any] = [:],
                     completion: ((Any?) -> Void)? = nil) {
        webView.callAsyncJavaScript(body, arguments: args, in: nil, in: .defaultClient) { result in
            switch result {
            case .success(let value): completion?(value)
            case .failure: completion?(nil)
            }
        }
    }
}

// MARK: - Injected JavaScript

private enum JS {
    /// Shared: convert fractions of the visible area into page coordinates.
    static let point = """
    const vv = window.visualViewport;
    const x = vv ? vv.offsetLeft + fx * vv.width : fx * window.innerWidth;
    const y = vv ? vv.offsetTop + fy * vv.height : fy * window.innerHeight;
    """

    static let click = point + """
    const el = document.elementFromPoint(x, y);
    if (!el) return false;
    const o = { bubbles: true, cancelable: true, composed: true, view: window,
                clientX: x, clientY: y, button: 0, pointerType: 'mouse', isPrimary: true };
    el.dispatchEvent(new PointerEvent('pointerdown', o));
    el.dispatchEvent(new MouseEvent('mousedown', o));
    if (typeof el.focus === 'function') el.focus({ preventScroll: true });
    el.dispatchEvent(new PointerEvent('pointerup', o));
    el.dispatchEvent(new MouseEvent('mouseup', o));
    el.dispatchEvent(new MouseEvent('click', o));
    return true;
    """

    static let scroll = point + """
    const w = vv ? vv.width : window.innerWidth;
    const h = vv ? vv.height : window.innerHeight;
    const dx = dfx * w, dy = dfy * h;
    let el = document.elementFromPoint(x, y);
    while (el && el !== document.body && el !== document.documentElement) {
      const s = getComputedStyle(el);
      const canY = /(auto|scroll)/.test(s.overflowY) && el.scrollHeight > el.clientHeight;
      const canX = /(auto|scroll)/.test(s.overflowX) && el.scrollWidth > el.clientWidth;
      if ((canY && dy !== 0) || (canX && dx !== 0)) { el.scrollBy(dx, dy); return true; }
      el = el.parentElement;
    }
    window.scrollBy(dx, dy);
    return true;
    """

    static let setValue = """
    function setValue(el, v) {
      const d = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(el), 'value');
      if (d && d.set) d.set.call(el, v); else el.value = v;
      el.dispatchEvent(new Event('input', { bubbles: true }));
    }
    """

    static let typeText = setValue + """
    const el = document.activeElement;
    if (!el || el === document.body) return false;
    if (el.isContentEditable) { document.execCommand('insertText', false, text); return true; }
    if ('value' in el) { setValue(el, el.value + text); return true; }
    return false;
    """

    static let backspace = setValue + """
    const el = document.activeElement;
    if (!el) return false;
    if (el.isContentEditable) { document.execCommand('delete'); return true; }
    if ('value' in el) { setValue(el, el.value.slice(0, -1)); return true; }
    return false;
    """

    static let enter = """
    const el = document.activeElement;
    if (!el) return false;
    const o = { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true };
    const notCancelled = el.dispatchEvent(new KeyboardEvent('keydown', o));
    el.dispatchEvent(new KeyboardEvent('keypress', o));
    el.dispatchEvent(new KeyboardEvent('keyup', o));
    if (notCancelled && el.form) {
      if (el.form.requestSubmit) el.form.requestSubmit(); else el.form.submit();
    }
    return true;
    """

    static let toggleVideoFill = """
    const id = '__bigscreen_fill';
    const existing = document.getElementById(id);
    if (existing) {
      existing.remove();
      document.querySelectorAll('[data-bigscreen-fill]').forEach(v => v.removeAttribute('data-bigscreen-fill'));
      return false;
    }
    const videos = Array.from(document.querySelectorAll('video'));
    if (videos.length === 0) return null;
    videos.sort((a, b) => (b.clientWidth * b.clientHeight) - (a.clientWidth * a.clientHeight));
    const target = videos.find(v => !v.paused) || videos[0];
    target.setAttribute('data-bigscreen-fill', '1');
    const style = document.createElement('style');
    style.id = id;
    style.textContent = `
      video[data-bigscreen-fill] {
        position: fixed !important; inset: 0 !important;
        width: 100vw !important; height: 100vh !important;
        max-width: none !important; max-height: none !important;
        z-index: 2147483647 !important; object-fit: contain !important;
        background: #000 !important; transform: none !important;
      }
      html, body { overflow: hidden !important; }`;
    document.head.appendChild(style);
    return true;
    """
}
