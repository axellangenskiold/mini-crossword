import SwiftUI

struct EdgeSwipeBackModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var didTriggerDismiss = false

    private let edgeWidth: CGFloat = 28
    private let minimumHorizontalTravel: CGFloat = 90
    private let maximumVerticalTravel: CGFloat = 80

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .local)
                    .onChanged { value in
                        guard !didTriggerDismiss else { return }
                        guard value.startLocation.x <= edgeWidth else { return }
                        guard value.translation.width >= minimumHorizontalTravel else { return }
                        guard abs(value.translation.height) <= maximumVerticalTravel else { return }
                        didTriggerDismiss = true
                        dismiss()
                    }
                    .onEnded { _ in
                        didTriggerDismiss = false
                    }
            )
    }
}

extension View {
    func edgeSwipeBackEnabled() -> some View {
        modifier(EdgeSwipeBackModifier())
    }
}

