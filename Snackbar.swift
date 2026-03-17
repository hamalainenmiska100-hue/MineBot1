import SwiftUI

struct SnackbarHost: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                if let snackbar = appModel.snackbar {
                    SnackbarView(
                        snackbar: snackbar,
                        onDismiss: dismissSnackbar
                    )
                    .frame(maxWidth: 640)
                    .padding(.horizontal, 14)
                    .padding(.bottom, max(12, proxy.safeAreaInsets.bottom == 0 ? 12 : proxy.safeAreaInsets.bottom))
                    .transition(snackbarTransition)
                    .zIndex(999)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(containerAnimation, value: appModel.snackbar?.id)
    }

    private var containerAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.18)
            : .spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.12)
    }

    private var snackbarTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }

        return .asymmetric(
            insertion: .move(edge: .bottom)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.96, anchor: .bottom)),
            removal: .move(edge: .bottom)
                .combined(with: .opacity)
        )
    }

    private func dismissSnackbar() {
        withAnimation(containerAnimation) {
            appModel.snackbar = nil
        }
    }
}

struct SnackbarView: View {
    let snackbar: SnackbarData
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragOffsetY: CGFloat = 0
    @State private var dragOffsetX: CGFloat = 0
    @State private var timerProgress: CGFloat = 1
    @State private var hasAppeared = false

    // Tweak this only if you also change AppModel's auto-dismiss time.
    private let visibleDuration: Double = 2.45

    private var accentColor: Color {
        switch snackbar.style {
        case .info:
            return Color.blue
        case .success:
            return Color.green
        case .error:
            return Color.red
        }
    }

    private var iconName: String {
        switch snackbar.style {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.octagon.fill"
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

    private var currentOpacity: Double {
        let verticalFade = 1 - min(max(dragOffsetY, 0) / 140, 1)
        let horizontalFade = 1 - min(abs(dragOffsetX) / 220, 1)
        return min(verticalFade, horizontalFade)
    }

    private var cardScale: CGFloat {
        if reduceMotion { return 1 }
        let interactionCompression = min(max(dragOffsetY, 0) / 500, 0.03)
        return hasAppeared ? (1 - interactionCompression) : 0.97
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        VStack(spacing: 0) {
            progressRail

            HStack(alignment: .top, spacing: 12) {
                iconBadge

                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentColor)

                    Text(snackbar.message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                dismissButton
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 13)
        }
        .background(
            ZStack(alignment: .leading) {
                shape.fill(.ultraThinMaterial)

                shape.fill(Color.primary.opacity(0.035))

                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.16),
                            accentColor.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.95),
                                accentColor.opacity(0.42)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4)
                    .clipShape(shape)
            }
        )
        .clipShape(shape)
        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)
        .shadow(color: accentColor.opacity(0.08), radius: 12, x: 0, y: 4)
        .scaleEffect(cardScale, anchor: .bottom)
        .offset(x: dragOffsetX * 0.22, y: max(0, dragOffsetY))
        .opacity(currentOpacity)
        .gesture(dismissGesture)
        .onAppear {
            hasAppeared = true

            if !reduceMotion {
                withAnimation(.linear(duration: visibleDuration)) {
                    timerProgress = 0
                }
            } else {
                timerProgress = 0
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(titleText). \(snackbar.message)")
    }

    private var progressRail: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.95),
                                accentColor.opacity(0.55)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * timerProgress))
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.14))
                .frame(width: 36, height: 36)

            Circle()
                .stroke(accentColor.opacity(0.18), lineWidth: 1)

            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accentColor)
        }
    }

    private var dismissButton: some View {
        Button {
            dismissNow()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let x = value.translation.width
                let y = value.translation.height

                dragOffsetX = x
                dragOffsetY = max(0, y)
            }
            .onEnded { value in
                let predictedY = value.predictedEndTranslation.height
                let predictedX = value.predictedEndTranslation.width

                let shouldDismiss =
                    value.translation.height > 70 ||
                    predictedY > 120 ||
                    abs(value.translation.width) > 120 ||
                    abs(predictedX) > 180

                if shouldDismiss {
                    dismissNow()
                } else {
                    let resetAnimation: Animation = reduceMotion
                        ? .easeOut(duration: 0.16)
                        : .interactiveSpring(response: 0.26, dampingFraction: 0.84, blendDuration: 0.10)

                    withAnimation(resetAnimation) {
                        dragOffsetX = 0
                        dragOffsetY = 0
                    }
                }
            }
    }

    private func dismissNow() {
        let dismissalAnimation: Animation = reduceMotion
            ? .easeOut(duration: 0.14)
            : .interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.10)

        withAnimation(dismissalAnimation) {
            dragOffsetY = 120
            dragOffsetX = 0
            timerProgress = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            onDismiss()
        }
    }
}
