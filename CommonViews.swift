import SwiftUI

struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(color.opacity(configuration.isPressed ? 0.12 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct StatusBadge: View {
    let status: String

    private var color: Color {
        switch status.lowercased() {
        case "connected": return .green
        case "reconnecting": return .green
        case "error": return .red
        case "starting": return .green
        case "disconnected": return .orange
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.headline)
        }
        .foregroundStyle(.primary)
    }

    private var label: String {
        switch status.lowercased() {
        case "connected": return "Connected"
        case "reconnecting": return "Connected"
        case "starting": return "Bot Online"
        case "error": return "Error"
        case "disconnected": return "Disconnected"
        default: return "Offline"
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
    }
}


struct RemoteMaintenanceOverlay: View {
    let maintenance: RemoteMaintenanceState
    let primaryAction: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack {
                CardView {
                    HStack(spacing: 12) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)

                        Text(maintenance.resolvedTitle)
                            .font(.title3.weight(.bold))
                    }

                    Text(maintenance.resolvedMessage)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Button(maintenance.resolvedButtonText, action: primaryAction)
                        .buttonStyle(PrimaryButtonStyle(color: .orange))
                }
                .padding(.horizontal, 20)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}

struct RemoteAnnouncementOverlay: View {
    let item: RemoteAnnouncementItem
    let primaryAction: () -> Void
    let secondaryAction: () -> Void
    let pollSelectionAction: (String) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack {
                CardView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let accentEmoji = item.customScreen?.accentEmoji,
                           !accentEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(accentEmoji)
                                .font(.system(size: 34))
                        }

                        Text(item.resolvedTitle)
                            .font(.title3.weight(.bold))

                        if let imageURLString = item.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
                           let imageURL = URL(string: imageURLString) {
                            AsyncImage(url: imageURL) { phase in
                                switch phase {
                                case .empty:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color(.tertiarySystemBackground))

                                        ProgressView()
                                    }
                                    .frame(height: 180)

                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 180)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                                case .failure:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color(.tertiarySystemBackground))

                                        VStack(spacing: 8) {
                                            Image(systemName: "photo")
                                                .font(.title3)
                                            Text("Image could not load.")
                                                .font(.caption)
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                    .frame(height: 180)

                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }

                        Text(item.resolvedMessage)
                            .font(.body)
                            .foregroundStyle(.secondary)

                        if let poll = item.poll, !poll.options.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                if let question = poll.question,
                                   !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(question)
                                        .font(.headline)
                                }

                                ForEach(poll.options, id: \.self) { option in
                                    Button {
                                        pollSelectionAction(option)
                                    } label: {
                                        HStack {
                                            Text(option)
                                            Spacer()
                                            Image(systemName: "checkmark.circle")
                                        }
                                    }
                                    .buttonStyle(SecondaryButtonStyle(color: .blue))
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            Button(item.resolvedSecondaryButtonText, action: secondaryAction)
                                .buttonStyle(SecondaryButtonStyle(color: .gray))

                            Button(item.resolvedPrimaryButtonText, action: primaryAction)
                                .buttonStyle(PrimaryButtonStyle(color: .blue))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}
