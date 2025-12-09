import SwiftUI

struct PhoneNumberPromptSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @Binding var isPresented: Bool
    let onSave: (String) -> Void
    let onSkip: () -> Void

    @State private var phoneNumber = ""
    @State private var isSaving = false
    @FocusState private var isPhoneFieldFocused: Bool

    // Common country codes for quick selection
    private let countryCodes = [
        ("+1", "US"),
        ("+44", "UK"),
        ("+61", "AU"),
        ("+81", "JP"),
        ("+82", "KR"),
        ("+86", "CN"),
        ("+91", "IN")
    ]

    @State private var selectedCountryCode = "+1"

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            VStack(spacing: 20) {
                // Title
                Text("add your phone number")
                    .font(.lora(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 24)

                // Subtitle
                Text("so friends can find you on phlock")
                    .font(.lora(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                // Phone input
                HStack(spacing: 12) {
                    // Country code picker
                    Menu {
                        ForEach(countryCodes, id: \.0) { code, country in
                            Button {
                                selectedCountryCode = code
                            } label: {
                                Text("\(code) \(country)")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedCountryCode)
                                .font(.lora(size: 17))
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }

                    // Phone number field
                    TextField("(555) 123-4567", text: $phoneNumber)
                        .font(.lora(size: 17))
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .focused($isPhoneFieldFocused)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                // Continue button
                Button {
                    savePhoneNumber()
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                                .tint(Color.background(for: colorScheme))
                        } else {
                            Text("continue")
                                .font(.lora(size: 17, weight: .semiBold))
                        }
                    }
                    .foregroundColor(Color.background(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isValidPhone ? Color.primaryColor(for: colorScheme) : Color.secondary.opacity(0.3))
                    .cornerRadius(16)
                }
                .disabled(!isValidPhone || isSaving)
                .padding(.horizontal, 24)

                // Skip button
                Button {
                    onSkip()
                    isPresented = false
                } label: {
                    Text("skip for now")
                        .font(.lora(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            // Focus the phone field after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPhoneFieldFocused = true
            }
        }
    }

    // Basic validation - at least 7 digits
    private var isValidPhone: Bool {
        let digitsOnly = phoneNumber.filter { $0.isNumber }
        return digitsOnly.count >= 7
    }

    private func savePhoneNumber() {
        guard isValidPhone else { return }

        isSaving = true

        // Combine country code and phone number
        let fullPhone = selectedCountryCode + phoneNumber

        // Call the save callback
        onSave(fullPhone)

        // Brief delay to show saving state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSaving = false
            isPresented = false
        }
    }
}

#Preview {
    PhoneNumberPromptSheet(
        isPresented: .constant(true),
        onSave: { phone in print("Saved: \(phone)") },
        onSkip: { print("Skipped") }
    )
}
