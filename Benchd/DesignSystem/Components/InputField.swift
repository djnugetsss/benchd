import SwiftUI

/// A single-line text input.
///
/// Deliberately not a bordered `TextField`: the system style draws a grey
/// rounded rect that reads as a form, and this app is never a form. The field is
/// a quiet recessed surface that grows a hairline accent border on focus — the
/// only accent on the sign-in and connect screens.
struct InputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .never
    var submitLabel: SubmitLabel = .done
    var isEnabled: Bool = true
    /// Shows the field in its error treatment. The message itself belongs in an
    /// `InlineMessage` beneath, not inside the field.
    var hasError: Bool = false
    var onSubmit: () -> Void = {}

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .statLabelStyle()

            HStack(spacing: Spacing.xs) {
                TextField(placeholder, text: $text)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                    .tint(Palette.accentInk)
                    .keyboardType(keyboard)
                    .textContentType(contentType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .submitLabel(submitLabel)
                    .focused($isFocused)
                    .disabled(!isEnabled)
                    .onSubmit(onSubmit)

                if !text.isEmpty && isEnabled {
                    Button {
                        text = ""
                        isFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(Typography.iconSmall)
                            .foregroundStyle(Palette.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear \(label)")
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(Palette.surfaceSecondary, in: RoundedRectangle.soft(Radius.md))
            .overlay(
                RoundedRectangle.soft(Radius.md)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .opacity(isEnabled ? 1 : 0.5)
            .animation(Motion.gentle, value: isFocused)
            .animation(Motion.gentle, value: hasError)
            .animation(Motion.quick, value: text.isEmpty)
        }
    }

    private var borderColor: Color {
        if hasError { Palette.negative.opacity(0.55) }
        else if isFocused { Palette.accent }
        else { Palette.divider }
    }

    /// Focus and error both read at 1pt — never a heavy stroke.
    private var borderWidth: CGFloat {
        (isFocused || hasError) ? Stroke.border : Stroke.hairline
    }
}

#Preview("InputField") {
    @Previewable @State var empty = ""
    @Previewable @State var filled = "anshmehta"
    @Previewable @State var invalid = "nobody"

    return VStack(spacing: Spacing.lg) {
        InputField(label: "Email", placeholder: "you@example.com", text: $empty, keyboard: .emailAddress)
        InputField(label: "Sleeper username", placeholder: "username", text: $filled)
        InputField(label: "Sleeper username", placeholder: "username", text: $invalid, hasError: true)
        InputField(label: "Disabled", placeholder: "…", text: $empty, isEnabled: false)
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .gradientBackground()
}
