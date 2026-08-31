import SwiftUI

private enum PDFProtectionChoice: String, CaseIterable, Identifiable {
    case none
    case password

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "No password"
        case .password: return "With password"
        }
    }
}

struct ExportPDFSheet: View {
    let documentTitle: String
    let onExport: (String?) -> Void
    let onCancel: () -> Void

    @State private var protectionChoice: PDFProtectionChoice = .none
    @State private var password = ""
    @State private var confirmPassword = ""

    private var usePasswordProtection: Bool {
        protectionChoice == .password
    }

    private var canExport: Bool {
        guard usePasswordProtection else { return true }
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return false }
        return trimmed == confirmPassword
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(documentTitle)
                        .font(.headline)
                } header: {
                    Text("Document")
                }

                Section {
                    Picker("PDF protection", selection: $protectionChoice) {
                        ForEach(PDFProtectionChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(
                        usePasswordProtection
                            ? "Recipients will need the password to open this PDF in Preview, Files, or other apps."
                            : "The PDF will open without a password."
                    )
                }

                if usePasswordProtection {
                    Section {
                        SecureField("Password", text: $password)
                            .textContentType(.newPassword)
                        SecureField("Confirm password", text: $confirmPassword)
                            .textContentType(.newPassword)
                    } header: {
                        Text("Set PDF password")
                    } footer: {
                        if !password.isEmpty && password.count < 4 {
                            Text("Use at least 4 characters.")
                                .foregroundStyle(.red)
                        } else if !confirmPassword.isEmpty && password != confirmPassword {
                            Text("Passwords do not match.")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Export PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
                        onExport(usePasswordProtection ? trimmed : nil)
                    }
                    .disabled(!canExport)
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: protectionChoice) { _, newValue in
                if newValue == .none {
                    password = ""
                    confirmPassword = ""
                }
            }
        }
    }
}
