import SwiftUI

struct SnackbarHost: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        Group {
            if let snackbar = appModel.snackbar {
                SnackbarView(snackbar: snackbar)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        )
                    )
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: appModel.snackbar?.id)
    }
}

struct SnackbarView: View {
    let snackbar: SnackbarData

    private var accentColor: Color {
        switch snackbar.style {
        case .info:
            return .blue
        case .success:
            return .green
        case .error:
            return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(accentColor)
                .frame(width: 10, height: 10)

            Text(snackbar.message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.thinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
    }
}
