import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var code = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 64, height: 64)

                                Image(systemName: "lock.shield.fill")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sign in")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(.white)

                                Text("Use your access code to continue.")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.84))
                            }
                        }

                        Text("Access code")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Access Code")
                                .font(.headline)

                            TextField("XXXX-XXXX-XXXX", text: $code)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled(true)
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .onChange(of: code) { _, newValue in
                                    let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
                                    code = String(filtered.prefix(14))
                                }
                        }
                    }

                    Button {
                        Task {
                            await appModel.login(code: code)
                        }
                    } label: {
                        Text(appModel.isBusy ? "Loading..." : "Login")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .blue))
                    .disabled(appModel.isBusy)
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .scrollIndicators(.hidden)
        }
    }
}
