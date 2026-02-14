import SwiftUI

/// Detent options for sheet presentation that work on iOS 15+.
/// On iOS 15, the sheet displays at full height (system default).
/// On iOS 16+, the specified detents and drag indicator are applied.
enum SheetDetent {
    case medium
    case large
}

/// A ViewModifier that conditionally applies `presentationDetents` and
/// `presentationDragIndicator` only on iOS 16+, keeping iOS 15 compatibility.
struct SheetPresentationModifier: ViewModifier {
    let detents: [SheetDetent]
    var showDragIndicator: Bool = false

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents(detentSet)
                .presentationDragIndicator(showDragIndicator ? .visible : .hidden)
        } else {
            content
        }
    }

    @available(iOS 16.0, *)
    private var detentSet: Set<PresentationDetent> {
        var set = Set<PresentationDetent>()
        for detent in detents {
            switch detent {
            case .medium:
                set.insert(.medium)
            case .large:
                set.insert(.large)
            }
        }
        return set
    }
}
