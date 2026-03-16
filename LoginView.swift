import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var code = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MineBot")
                            .font(.system(size: 34, weight: .bold))
                        Text("Enter your access code")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
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
        }
    }
}
