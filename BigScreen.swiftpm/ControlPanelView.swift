import SwiftUI

/// The iPad screen. Without a monitor it's a normal browser; with a monitor
/// plugged in, the page moves to the monitor and the iPad becomes a remote.
struct ControlPanelView: View {
    @EnvironmentObject private var browser: BrowserController
    @State private var typed = ""

    private let quickLinks: [(String, String)] = [
        ("YouTube", "https://www.youtube.com"),
        ("Google", "https://www.google.com"),
        ("Vimeo", "https://vimeo.com"),
        ("Wikipedia", "https://www.wikipedia.org")
    ]

    var body: some View {
        VStack(spacing: 12) {
            toolbar
            ProgressView(value: browser.progress)
                .opacity(browser.isLoading ? 1 : 0)
            quickLinkRow

            if browser.isExternalConnected {
                trackpad
                remoteControls
            } else {
                notConnectedBanner
                WebViewContainer(webView: browser.webView)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .bottom) {
            if let message = browser.statusMessage {
                Text(message)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: browser.statusMessage)
        .animation(.default, value: browser.isExternalConnected)
    }

    // MARK: - Sections

    private var toolbar: some View {
        HStack(spacing: 14) {
            Button { browser.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(!browser.canGoBack)
            Button { browser.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(!browser.canGoForward)
            Button { browser.reloadOrStop() } label: {
                Image(systemName: browser.isLoading ? "xmark" : "arrow.clockwise")
            }

            TextField("Search or enter website", text: $browser.addressText)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.webSearch)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit { browser.load(browser.addressText) }

            connectionBadge
        }
        .font(.title3)
    }

    private var connectionBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: browser.isExternalConnected ? "display" : "display.trianglebadge.exclamationmark")
            if browser.isExternalConnected {
                Text("\(Int(browser.externalResolution.width))×\(Int(browser.externalResolution.height))")
                    .font(.footnote.monospacedDigit())
            }
        }
        .foregroundStyle(browser.isExternalConnected ? .green : .secondary)
    }

    private var quickLinkRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(quickLinks, id: \.1) { name, url in
                    Button(name) { browser.load(url) }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private var notConnectedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "cable.connector")
            Text("Plug in a monitor with a USB‑C or HDMI adapter — this page will move onto it and fill the whole screen.")
                .font(.callout)
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var trackpad: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
            VStack(spacing: 8) {
                Image(systemName: "hand.point.up.left")
                    .font(.largeTitle)
                Text("Trackpad")
                    .font(.headline)
                Text("Drag one finger to move the pointer · Tap to click · Drag two fingers to scroll")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
            .padding()
            .allowsHitTesting(false)

            TrackpadView(
                onMove: { dx, dy, speed in browser.moveCursor(dx: dx, dy: dy, speed: speed) },
                onScroll: { dx, dy in browser.scroll(dx: dx, dy: dy) },
                onTap: { browser.click() }
            )
        }
        .frame(maxHeight: .infinity)
    }

    private var remoteControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TextField("Type into the selected box on the monitor…", text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .onSubmit(sendTyped)
                Button("Send", action: sendTyped)
                    .buttonStyle(.bordered)
                Button { browser.pressBackspace() } label: { Image(systemName: "delete.left") }
                    .buttonStyle(.bordered)
                Button { browser.pressEnter() } label: { Image(systemName: "return") }
                    .buttonStyle(.bordered)
            }

            HStack(spacing: 10) {
                Button { browser.toggleVideoFill() } label: {
                    Label(browser.videoFillOn ? "Exit video fill" : "Fill screen with video",
                          systemImage: browser.videoFillOn
                            ? "arrow.down.right.and.arrow.up.left"
                            : "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.borderedProminent)

                Button { browser.page(down: false) } label: { Image(systemName: "chevron.up.2") }
                    .buttonStyle(.bordered)
                Button { browser.page(down: true) } label: { Image(systemName: "chevron.down.2") }
                    .buttonStyle(.bordered)

                Spacer()

                Toggle("Pointer", isOn: $browser.showCursor)
                    .fixedSize()
            }

            HStack(spacing: 10) {
                Image(systemName: "textformat.size")
                Slider(value: $browser.zoom, in: 0.5...3, step: 0.1)
                Text("\(Int((browser.zoom * 100).rounded()))%")
                    .font(.footnote.monospacedDigit())
                    .frame(width: 48)

                Image(systemName: "cursorarrow.motionlines")
                Slider(value: $browser.sensitivity, in: 0.5...4)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func sendTyped() {
        browser.type(typed)
        typed = ""
    }
}
