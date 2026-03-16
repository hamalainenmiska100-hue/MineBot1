import SwiftUI

struct AddServerView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var ipAddress = ""
    @State private var port = "19132"

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("IP Address", text: $ipAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)

                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveServer()
                    }
                    .disabled(ipAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Int(port) == nil)
                }
            }
        }
    }

    private func saveServer() {
        let cleanedPort = Int(port) ?? 19132
        appModel.addServer(ip: ipAddress, port: cleanedPort)
        dismiss()
    }
}
