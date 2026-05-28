import SwiftUI
import UIKit
import Combine

struct TouchDot: Identifiable {
    let id: ObjectIdentifier
    let location: CGPoint
}

/// Holds the live touch locations to draw. Updated from the window gesture
/// recognizer (main thread) and observed by the overlay.
final class TouchIndicatorState: ObservableObject {
    @Published var dots: [TouchDot] = []

    func update(_ touches: [ObjectIdentifier: CGPoint]) {
        dots = touches.map { TouchDot(id: $0.key, location: $0.value) }
    }

    func clear() { dots = [] }
}

/// A gesture recognizer that never recognizes — it only observes touches and
/// reports their locations, so it never cancels or delays real interactions.
private final class TouchReporter: UIGestureRecognizer {
    var onChange: (([ObjectIdentifier: CGPoint]) -> Void)?
    private var active: [ObjectIdentifier: UITouch] = [:]

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches { active[ObjectIdentifier(touch)] = touch }
        report()
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) { report() }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches { active.removeValue(forKey: ObjectIdentifier(touch)) }
        report()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches { active.removeValue(forKey: ObjectIdentifier(touch)) }
        report()
    }
    override func reset() {
        active.removeAll()
        report()
    }

    private func report() {
        var map: [ObjectIdentifier: CGPoint] = [:]
        for (id, touch) in active { map[id] = touch.location(in: view) }
        onChange?(map)
    }
}

/// Installs the touch reporter on the key window while present; removes it on teardown.
private struct TouchReporterInstaller: UIViewRepresentable {
    let state: TouchIndicatorState

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        context.coordinator.state = state
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard context.coordinator.recognizer == nil,
              let window = uiView.window ?? Self.keyWindow else { return }
        let recognizer = TouchReporter()
        recognizer.delegate = context.coordinator
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.onChange = { [weak state] map in state?.update(map) }
        window.addGestureRecognizer(recognizer)
        context.coordinator.recognizer = recognizer
        context.coordinator.window = window
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        if let recognizer = coordinator.recognizer {
            coordinator.window?.removeGestureRecognizer(recognizer)
        }
        coordinator.recognizer = nil
        coordinator.state?.clear()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var recognizer: UIGestureRecognizer?
        weak var window: UIWindow?
        weak var state: TouchIndicatorState?
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}

/// Root overlay that draws a pointer following each active touch. Inert to hit
/// testing so it never interferes with the app.
struct TouchIndicatorOverlay: View {
    @EnvironmentObject private var settings: DebugSettings
    @EnvironmentObject private var touchState: TouchIndicatorState

    var body: some View {
        if settings.showTouches {
            ZStack {
                TouchReporterInstaller(state: touchState).frame(width: 0, height: 0)
                ForEach(touchState.dots) { dot in
                    Circle()
                        .fill(Color.yellow.opacity(0.35))
                        .overlay(Circle().stroke(Color.yellow, lineWidth: 2))
                        .frame(width: 22, height: 22)
                        .position(dot.location)
                        .animation(.easeOut(duration: 0.08), value: dot.location)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
