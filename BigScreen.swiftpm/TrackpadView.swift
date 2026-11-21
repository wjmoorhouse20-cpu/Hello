import SwiftUI
import UIKit

/// A touch surface on the iPad that drives the pointer on the monitor.
/// One finger drags the pointer, a tap clicks, two fingers scroll.
struct TrackpadView: UIViewRepresentable {
    var onMove: (CGFloat, CGFloat, CGFloat) -> Void   // dx, dy, speed
    var onScroll: (CGFloat, CGFloat) -> Void          // dx, dy
    var onTap: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true

        let move = UIPanGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.handleMove(_:)))
        move.minimumNumberOfTouches = 1
        move.maximumNumberOfTouches = 1

        let scroll = UIPanGestureRecognizer(target: context.coordinator,
                                            action: #selector(Coordinator.handleScroll(_:)))
        scroll.minimumNumberOfTouches = 2
        scroll.maximumNumberOfTouches = 2

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))

        [move, scroll, tap].forEach(view.addGestureRecognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: TrackpadView
        init(parent: TrackpadView) { self.parent = parent }

        @objc func handleMove(_ g: UIPanGestureRecognizer) {
            guard g.state == .changed, let v = g.view else { return }
            let t = g.translation(in: v)
            let vel = g.velocity(in: v)
            g.setTranslation(.zero, in: v)
            parent.onMove(t.x, t.y, hypot(vel.x, vel.y))
        }

        @objc func handleScroll(_ g: UIPanGestureRecognizer) {
            guard g.state == .changed, let v = g.view else { return }
            let t = g.translation(in: v)
            g.setTranslation(.zero, in: v)
            // "Natural" scrolling, like a Mac trackpad: push content up to go down.
            parent.onScroll(-t.x * 2, -t.y * 2)
        }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            if g.state == .ended { parent.onTap() }
        }
    }
}
