import SwiftUI

@main
struct BigScreenApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var browser = BrowserController.shared

    var body: some Scene {
        WindowGroup {
            ControlPanelView()
                .environmentObject(browser)
        }
    }
}
