import SwiftUI

struct SnackbarHost: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        VStack {
            Spacer()

            if let snackbar = appModel.snackbar {
                SnackbarView(
                    snackbar: snackbar,
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                            appModel.snackbar = nil
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    )
                )
                .zIndex(999)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: appModel.snackbar?.id)
        .allowsHitTesting(false)
    }
}

struct SnackbarView: View {
    let snackbar: SnackbarData
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

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

    private var iconName: String {
        switch snackbar.style {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }

    private var titleText: String {
        switch snackbar.style {
        case .info:
            return "Notice"
        case .success:
            return "Success"
        case .error:
            return "Error"
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)

                Text(snackbar.message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            ZStack(alignment: .leading) {
                shape
                    .fill(.ultraThinMaterial)

                shape
                    .fill(Color.white.opacity(0.03))

                Rectangle()
                    .fill(accentColor)
                    .frame(width: 4)
                    .clipShape(shape)

                shape
                    .stroke(accentColor.opacity(0.18), lineWidth: 1)
            }
        )
        .clipShape(shape)
        .shadow(color: .black.opacity(0.16), radius: 14, y: 8)
        .offset(y: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    dragOffset = max(0, value.translation.height)
                }
                .onEnded { value in
                    if value.translation.height > 50 {
                        onDismiss()
                    } else {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .allowsHitTesting(true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(titleText). \(snackbar.message)")
    }
}
