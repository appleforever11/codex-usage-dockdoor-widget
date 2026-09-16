import AppKit
import SwiftUI

/// Observes horizontal trackpad scroll events without taking ownership of the
/// vertical card scroll view or the native card drag session. macOS two-finger
/// trackpad swipes arrive as scroll-wheel events.
struct CodexTrackpadSwipeBridge: NSViewRepresentable {
    let onSwipe: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSwipe: onSwipe)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.install(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onSwipe = onSwipe
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.remove()
    }

    final class Coordinator {
        var onSwipe: (Int) -> Void

        private var monitor: Any?
        private weak var observedView: NSView?
        private var accumulatedHorizontalDelta: CGFloat = 0
        private var lastSwipeUptime: TimeInterval = 0

        init(onSwipe: @escaping (Int) -> Void) {
            self.onSwipe = onSwipe
        }

        func install(for view: NSView) {
            observedView = view
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self, weak view] event in
                guard let self,
                      let view,
                      let window = view.window,
                      event.window === window
                else {
                    return event
                }
                return self.handle(event)
            }
        }

        func remove() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            observedView = nil
            accumulatedHorizontalDelta = 0
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            let horizontal = event.hasPreciseScrollingDeltas ? event.scrollingDeltaX : event.deltaX
            let vertical = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY
            let ended = event.phase.contains(.ended)
                || event.phase.contains(.cancelled)
                || event.momentumPhase.contains(.ended)

            if event.phase.contains(.began) {
                accumulatedHorizontalDelta = 0
            }

            guard abs(horizontal) > 0.5,
                  abs(horizontal) > abs(vertical) * 1.25
            else {
                if ended { accumulatedHorizontalDelta = 0 }
                return event
            }

            accumulatedHorizontalDelta += horizontal
            let now = ProcessInfo.processInfo.systemUptime

            if now - lastSwipeUptime < 0.65 {
                if ended { accumulatedHorizontalDelta = 0 }
                return nil
            }

            guard abs(accumulatedHorizontalDelta) >= 55 else {
                if ended { accumulatedHorizontalDelta = 0 }
                return event
            }

            let offset = accumulatedHorizontalDelta < 0 ? 1 : -1
            accumulatedHorizontalDelta = 0
            lastSwipeUptime = now
            onSwipe(offset)
            return nil
        }
    }
}
