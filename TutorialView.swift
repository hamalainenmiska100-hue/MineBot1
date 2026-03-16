import SwiftUI

struct TutorialView: View {
    let onContinue: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MineBot")
                            .font(.system(size: 34, weight: .bold))
                        Text("Welcome.")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("This app lets you run a Minecraft AFK bot remotely from your phone.")
                                .font(.body)

                            VStack(alignment: .leading, spacing: 12) {
                                TutorialRow(number: "1", text: "Enter your access code")
                                TutorialRow(number: "2", text: "Link your Microsoft account")
                                TutorialRow(number: "3", text: "Start your bot")
                            }

                            Text("Your bot will stay online even when the app is closed.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        Haptics.light()
                        onContinue()
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .blue))
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct TutorialRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .frame(width: 24, height: 24)
                .background(Color.blue.opacity(0.12))
                .clipShape(Circle())
            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
