import SwiftUI

/// Sheet for adding or editing the message on a daily song pick
struct MessageEditorSheet: View {
    let initialMessage: String
    let shareId: UUID
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var message: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool

    private let maxLength = 280

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Text editor
                TextField("add an optional note about this song", text: $message, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...6)
                    .focused($isTextFieldFocused)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                // Character count
                HStack {
                    Spacer()
                    Text("\(message.count)/\(maxLength)")
                        .font(.caption)
                        .foregroundColor(message.count > maxLength ? .red : .secondary)
                }
                .padding(.horizontal)

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle(initialMessage.isEmpty ? "add message" : "edit message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") {
                        saveMessage()
                    }
                    .disabled(message.count > maxLength || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                message = initialMessage
                isTextFieldFocused = true
            }
            .interactiveDismissDisabled(isSaving)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func saveMessage() {
        guard !isSaving else { return }

        isSaving = true
        errorMessage = nil

        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                try await ShareService.shared.updateShareMessage(shareId: shareId, message: trimmedMessage)

                await MainActor.run {
                    onSave(trimmedMessage)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MessageEditorSheet(
        initialMessage: "This song reminds me of summer",
        shareId: UUID(),
        onSave: { _ in }
    )
}
