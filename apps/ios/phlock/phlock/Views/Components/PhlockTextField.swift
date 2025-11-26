import SwiftUI

struct PhlockTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var multiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.lora(size: 10))
                .foregroundColor(.primary)

            if multiline {
                TextEditor(text: $text)
                    .font(.lora(size: 10))
                    .frame(height: 100)
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            } else {
                TextField(placeholder, text: $text)
                    .font(.lora(size: 10))
                    .padding(16)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PhlockTextField(
            label: "Display Name",
            placeholder: "Your name",
            text: .constant("")
        )

        PhlockTextField(
            label: "Bio",
            placeholder: "Tell friends about your music taste...",
            text: .constant(""),
            multiline: true
        )
    }
    .padding()
}
