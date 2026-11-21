import SwiftUI
import UIKit

/// Routes the external-monitor scene to our own scene delegate.
///
/// When a monitor is plugged in, iPadOS offers the app a scene with the
/// `.windowExternalDisplayNonInteractive` role. If we accept it, the monitor
/// stops mirroring the iPad and shows whatever we put in that window instead —
/// edge to edge, at the monitor's native resolution and aspect ratio.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            let config = UISceneConfiguration(name: "External Display",
                                              sessionRole: connectingSceneSession.role)
            config.delegateClass = ExternalDisplaySceneDelegate.self
            return config
        }
        // Main iPad window: let SwiftUI handle it.
        return UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    }
}

final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Use every pixel of the monitor (no TV-style overscan shrinking).
        windowScene.screen.overscanCompensation = .none

        let browser = BrowserController.shared
        let nativeSize = windowScene.screen.nativeBounds.size
        browser.externalDisplayConnected(resolution: nativeSize)

        let host = UIHostingController(
            rootView: ExternalDisplayView().environmentObject(browser)
        )
        host.view.backgroundColor = .black

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        window.rootViewController = host
        window.isHidden = false
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window?.isHidden = true
        window = nil
        BrowserController.shared.externalDisplayDisconnected()
    }
}

/// What the monitor shows: the web page filling the whole screen plus a pointer.
struct ExternalDisplayView: View {
    @EnvironmentObject private var browser: BrowserController

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.black
                WebViewContainer(webView: browser.webView)

                if browser.showCursor && browser.cursorActive {
                    PointerView(pulse: browser.clickPulse)
                        .position(x: browser.cursor.x + 11, y: browser.cursor.y + 14)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.25), value: browser.cursorActive)
            .onAppear { browser.viewportSize = geo.size }
            .onChange(of: geo.size) { _, newSize in browser.viewportSize = newSize }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

private struct PointerView: View {
    let pulse: Int
    @State private var pressed = false

    var body: some View {
        Image(systemName: "cursorarrow")
            .font(.system(size: 30, weight: .regular))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.9), radius: 2)
            .scaleEffect(pressed ? 0.8 : 1)
            .onChange(of: pulse) { _, _ in
                withAnimation(.easeIn(duration: 0.08)) { pressed = true }
                withAnimation(.easeOut(duration: 0.15).delay(0.08)) { pressed = false }
            }
    }
}
