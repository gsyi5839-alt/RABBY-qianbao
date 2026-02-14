import SwiftUI

/// Slippage Settings Sheet - Configure swap slippage tolerance
/// Matches the Rabby browser extension slippage settings UI
struct SlippageSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var swapManager = SwapManager.shared

    @Binding var slippage: Double
    @Binding var isAutoSlippage: Bool

    // Local editing state
    @State private var selectedPreset: SlippagePreset? = nil
    @State private var customInput: String = ""
    @State private var isCustomActive: Bool = false
    @State private var localAutoSlippage: Bool = true
    @FocusState private var isCustomFieldFocused: Bool

    // MARK: - Preset values

    enum SlippagePreset: Double, CaseIterable, Identifiable {
        case low = 0.1
        case medium = 0.5
        case high = 1.0

        var id: Double { rawValue }

        var label: String {
            switch self {
            case .low: return "0.1%"
            case .medium: return "0.5%"
            case .high: return "1.0%"
            }
        }
    }

    // MARK: - Warning level

    private enum WarningLevel {
        case tooLow      // < 0.05%
        case safe         // 0.05% .. 5%
        case tooHigh      // > 5%
        case none         // auto mode or no input
    }

    private var currentValue: Double {
        if localAutoSlippage { return 0.5 }
        if let preset = selectedPreset, !isCustomActive { return preset.rawValue }
        return Double(customInput) ?? 0.5
    }

    private var warningLevel: WarningLevel {
        if localAutoSlippage { return .none }
        let value = currentValue
        if value < 0.05 { return .tooLow }
        if value > 5.0 { return .tooHigh }
        return .safe
    }

    private var isSaveEnabled: Bool {
        if localAutoSlippage { return true }
        if let _ = selectedPreset, !isCustomActive { return true }
        // Custom mode: must be a valid positive number
        guard let val = Double(customInput), val > 0 else { return false }
        return true
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        autoButton
                        presetButtons
                        customInputSection
                        warningBanner
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }

                saveButton
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L("Slippage Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel")) { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear(perform: syncFromBinding)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("Slippage Tolerance"))
                .font(.headline)
                .foregroundColor(.primary)

            Text(L("Your transaction will revert if the price changes unfavorably by more than this percentage."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Auto Button

    private var autoButton: some View {
        Button(action: selectAuto) {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.body)
                    .foregroundColor(localAutoSlippage ? .white : .blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Auto"))
                        .font(.body.weight(.semibold))
                        .foregroundColor(localAutoSlippage ? .white : .primary)
                    Text(L("Recommended for most trades"))
                        .font(.caption)
                        .foregroundColor(localAutoSlippage ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                if localAutoSlippage {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(localAutoSlippage ? Color.blue : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(localAutoSlippage ? Color.clear : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Preset Buttons

    private var presetButtons: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Or choose a preset"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(SlippagePreset.allCases) { preset in
                    presetButton(preset)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func presetButton(_ preset: SlippagePreset) -> some View {
        let isSelected = !localAutoSlippage && !isCustomActive && selectedPreset == preset

        return Button(action: { selectPreset(preset) }) {
            Text(preset.label)
                .font(.body.weight(.medium))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemBackground))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Input

    private var customInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Custom"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 0) {
                TextField(L("0.5"), text: $customInput)
                    .keyboardType(.decimalPad)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.leading)
                    .focused($isCustomFieldFocused)
                    .onChange(of: customInput) { _ in
                        activateCustomMode()
                    }
                    .onChange(of: isCustomFieldFocused) { focused in
                        if focused {
                            activateCustomMode()
                        }
                    }

                Text(L("%"))
                    .font(.body.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isCustomActive && !localAutoSlippage
                            ? Color.blue
                            : Color(.systemGray4),
                        lineWidth: isCustomActive && !localAutoSlippage ? 2 : 1
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Warning Banner

    @ViewBuilder
    private var warningBanner: some View {
        switch warningLevel {
        case .tooLow:
            warningRow(
                icon: "exclamationmark.triangle.fill",
                text: "Your transaction may fail",
                color: .orange
            )
        case .tooHigh:
            warningRow(
                icon: "exclamationmark.shield.fill",
                text: "Your transaction may be frontrun",
                color: .red
            )
        case .safe:
            warningRow(
                icon: "checkmark.seal.fill",
                text: "Slippage is within a safe range",
                color: .green
            )
        case .none:
            EmptyView()
        }
    }

    private func warningRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)

            Text(text)
                .font(.subheadline)
                .foregroundColor(color)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: save) {
            Text(L("Save"))
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSaveEnabled ? Color.blue : Color.gray)
                )
        }
        .disabled(!isSaveEnabled)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .padding(.top, 8)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions

    private func syncFromBinding() {
        localAutoSlippage = isAutoSlippage
        if isAutoSlippage {
            selectedPreset = nil
            isCustomActive = false
            customInput = ""
        } else {
            // Check if current slippage matches a preset
            if let preset = SlippagePreset.allCases.first(where: { $0.rawValue == slippage }) {
                selectedPreset = preset
                isCustomActive = false
                customInput = ""
            } else {
                selectedPreset = nil
                isCustomActive = true
                customInput = formatSlippage(slippage)
            }
        }
    }

    private func selectAuto() {
        localAutoSlippage = true
        selectedPreset = nil
        isCustomActive = false
        isCustomFieldFocused = false
    }

    private func selectPreset(_ preset: SlippagePreset) {
        localAutoSlippage = false
        selectedPreset = preset
        isCustomActive = false
        customInput = ""
        isCustomFieldFocused = false
    }

    private func activateCustomMode() {
        localAutoSlippage = false
        selectedPreset = nil
        isCustomActive = true
    }

    private func save() {
        if localAutoSlippage {
            isAutoSlippage = true
            slippage = 0.5
            swapManager.setAutoSlippage(true)
        } else if let preset = selectedPreset, !isCustomActive {
            isAutoSlippage = false
            slippage = preset.rawValue
            swapManager.setSlippage(formatSlippage(preset.rawValue))
        } else if let value = Double(customInput), value > 0 {
            isAutoSlippage = false
            slippage = value
            swapManager.setSlippage(formatSlippage(value))
        }
        dismiss()
    }

    private func formatSlippage(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        // Remove trailing zeros
        let formatted = String(format: "%.2f", value)
        var result = formatted
        while result.hasSuffix("0") { result = String(result.dropLast()) }
        if result.hasSuffix(".") { result = String(result.dropLast()) }
        return result
    }
}

// MARK: - Preview

#if DEBUG
struct SlippageSettingsSheet_Previews: PreviewProvider {
    static var previews: some View {
        SlippageSettingsSheet(
            slippage: .constant(0.5),
            isAutoSlippage: .constant(true)
        )
    }
}
#endif
