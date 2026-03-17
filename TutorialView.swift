import SwiftUI

struct TutorialView: View {
    let onContinue: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    stepsCard
                    footerCard

                    Button {
                        Haptics.light()
                        onContinue()
                    } label: {
                        HStack(spacing: 10) {
                            Text("Continue")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                                .font(.subheadline.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .blue))
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var heroCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MineBot")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("Remote control for your Minecraft AFK bot.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Everything important in one place — connect, monitor, and manage your bot from your phone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    TutorialPill(title: "Fast setup")
                    TutorialPill(title: "Remote control")
                    TutorialPill(title: "Runs in background")
                }
            }
        }
    }

    private var stepsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How it works")
                    .font(.headline)

                VStack(spacing: 14) {
                    TutorialStepRow(
                        number: "1",
                        title: "Enter your access code",
                        subtitle: "Use the code you received to sign in and unlock access."
                    )

                    TutorialStepRow(
                        number: "2",
                        title: "Link your Microsoft account",
                        subtitle: "Connect your account so the bot can join online servers."
                    )

                    TutorialStepRow(
                        number: "3",
                        title: "Choose a server and start",
                        subtitle: "Pick your saved server, select the connection type, and launch the bot."
                    )
                }
            }
        }
    }

    private var footerCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Good to know", systemImage: "info.circle")
                    .font(.headline)

                Text("Your bot can stay online even after you close the app. You can reopen MineBot anytime to check status, reconnect, or stop it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct TutorialStepRow: View {
    let number: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 34, height: 34)

                Text(number)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TutorialPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.06))
            .clipShape(Capsule())
    }
}
