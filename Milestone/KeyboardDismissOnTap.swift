import SwiftUI
import UIKit

private struct DismissKeyboardOnBackgroundTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            },
            including: .gesture
        )
    }
}

extension View {
    func dismissKeyboardOnBackgroundTap() -> some View {
        modifier(DismissKeyboardOnBackgroundTapModifier())
    }
}
