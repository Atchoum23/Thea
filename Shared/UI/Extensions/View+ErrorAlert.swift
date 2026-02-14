import SwiftUI

// MARK: - Error Alert

extension View {
    func alert(error: Binding<Error?>) -> some View {
        alert(
            "Error",
            isPresented: .constant(error.wrappedValue != nil),
            presenting: error.wrappedValue
        ) { _ in
            Button("OK") {
                error.wrappedValue = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}
