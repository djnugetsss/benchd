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
    /// Masks what is typed and swaps the clear button for a reveal toggle.
    ///
    /// A password field is this field with the characters hidden, not a
    /// different control — anything else and the one input on the sign-in screen
    /// would not match the one above it.
    var isSecure: Bool = false
    var onSubmit: () -> Void = {}

    @FocusState private var isFocused: Bool
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .statLabelStyle()

            HStack(spacing: Spacing.xs) {
                field
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

                if isSecure {
                    if !text.isEmpty && isEnabled {
                        trailingButton(
                            icon: isRevealed ? "eye.slash" : "eye",
                            label: isRevealed ? "Hide \(label)" : "Show \(label)"
                        ) {
                            isRevealed.toggle()
                        }
                    }
                } else if !text.isEmpty && isEnabled {
                    trailingButton(icon: "xmark.circle.fill", label: "Clear \(label)") {
                        text = ""
                        isFocused = true
                    }
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

    /// `SecureField` and `TextField` are different types, so the reveal toggle
    /// has to swap the view rather than a flag on one.
    @ViewBuilder
    private var field: some View {
        if isSecure && !isRevealed {
            SecureField(placeholder, text: $text)
        } else {
            TextField(placeholder, text: $text)
        }
    }

    private func trailingButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(Typography.iconSmall)
                .foregroundStyle(Palette.textTertiary)
                // Both glyphs occupy the same width, so revealing a password
                // does not nudge the field's contents sideways.
                .frame(width: Spacing.md, height: Spacing.md)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .transition(.opacity)
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
