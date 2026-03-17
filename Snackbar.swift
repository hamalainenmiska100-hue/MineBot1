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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
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
        .animation(.spring(response: 0.32, dampingFraction: 0.9), value: appModel.snackbar?.id)
    }
}

struct SnackbarView: View {
    let snackbar: SnackbarData
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    private let cornerRadius: CGFloat = 22

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
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accentColor)

                Text(snackbar.message)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(red: 0.14, green: 0.14, blue: 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.03), lineWidth: 0.8)
        )
        .overlay(alignment: .leading) {
            LeftAccentBar(color: accentColor, cornerRadius: cornerRadius)
        }
        .shadow(color: .black.opacity(0.22), radius: 14, y: 8)
        .offset(y: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    dragOffset = max(0, value.translation.height)
                }
                .onEnded { value in
                    if value.translation.height > 55 {
                        onDismiss()
                    } else {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(titleText). \(snackbar.message)")
    }
}

private struct LeftAccentBar: View {
    let color: Color
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { proxy in
            color
                .frame(width: 4, height: proxy.size.height)
                .clipShape(LeftBarShape(cornerRadius: cornerRadius))
        }
        .frame(width: 4)
    }
}

private struct LeftBarShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let r = min(cornerRadius, rect.height / 2, rect.width)

        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.minY + r),
            radius: r,
            startAngle: .degrees(-90),
            endAngle: .degrees(-180),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
            radius: r,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()

        return path
    }
}
