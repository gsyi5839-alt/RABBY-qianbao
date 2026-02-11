import SwiftUI

/// Complete wallet creation flow
struct CreateWalletView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var keyringManager = KeyringManager.shared
    
    @State private var currentStep = 0
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var mnemonic: [String] = []
    @State private var shuffledMnemonic: [String] = []
    @State private var selectedWords: [String] = []
    @State private var errorMessage = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Progress indicator
                ProgressView(value: Double(currentStep), total: 3)
                    .padding()
                
                // Step content
                Group {
                    switch currentStep {
                    case 0:
                        passwordStep
                    case 1:
                        mnemonicStep
                    case 2:
                        verifyStep
                    default:
                        EmptyView()
                    }
                }
                
                Spacer()
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("Back") {
                            currentStep -= 1
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Button(currentStep == 2 ? "Create Wallet" : "Next") {
                        handleNext()
                    }
                    .disabled(!canProceed)
                    .padding()
                    .frame(maxWidth: 200)
                    .background(canProceed ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Create Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Step 1: Password
    
    private var passwordStep: some View {
        VStack(spacing: 24) {
            Text("Set Password")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This password will protect your wallet")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            SecureField("Password (min 8 characters)", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
            
            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // Password strength indicator
            PasswordStrengthView(password: password)
        }
        .padding()
    }
    
    // MARK: - Step 2: Mnemonic Display
    
    private var mnemonicStep: some View {
        VStack(spacing: 24) {
            Text("Backup Secret Phrase")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Write down these 12 words in order. Keep them safe!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            // Warning
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Never share your secret phrase with anyone")
                    .font(.caption)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            
            // Mnemonic grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(mnemonic.enumerated()), id: \.offset) { index, word in
                    HStack {
                        Text("\(index + 1).")
                            .foregroundColor(.gray)
                            .frame(width: 30, alignment: .trailing)
                        Text(word)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            // Copy button
            Button(action: copyMnemonic) {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy to Clipboard")
                }
                .foregroundColor(.blue)
            }
        }
        .padding()
    }
    
    // MARK: - Step 3: Verify
    
    private var verifyStep: some View {
        VStack(spacing: 24) {
            Text("Verify Secret Phrase")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Select words in the correct order")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Selected words
            VStack(alignment: .leading, spacing: 8) {
                Text("Your sequence:")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if #available(iOS 16.0, *) {
                    FlowLayout(spacing: 8) {
                        ForEach(Array(selectedWords.enumerated()), id: \.offset) { index, word in
                            Button(action: { removeWord(at: index) }) {
                                HStack(spacing: 4) {
                                    Text("\(index + 1). \(word)")
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(20)
                            }
                        }
                    }
                } else {
                    // Fallback for iOS 15
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(selectedWords.enumerated()), id: \.offset) { index, word in
                            Button(action: { removeWord(at: index) }) {
                                HStack(spacing: 4) {
                                    Text("\(index + 1). \(word)")
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(20)
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 100)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Available words
            VStack(alignment: .leading, spacing: 8) {
                Text("Select words:")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if #available(iOS 16.0, *) {
                    FlowLayout(spacing: 8) {
                        ForEach(shuffledMnemonic.filter { !selectedWords.contains($0) }, id: \.self) { word in
                            Button(action: { selectWord(word) }) {
                                Text(word)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(20)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                } else {
                    // Fallback for iOS 15
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(shuffledMnemonic.filter { !selectedWords.contains($0) }, id: \.self) { word in
                            Button(action: { selectWord(word) }) {
                                Text(word)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(20)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding()
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func handleNext() {
        errorMessage = ""
        
        switch currentStep {
        case 0:
            guard validatePassword() else { return }
            generateMnemonic()
            currentStep = 1
            
        case 1:
            prepareMnemonicVerification()
            currentStep = 2
            
        case 2:
            createWallet()
            
        default:
            break
        }
    }
    
    private func validatePassword() -> Bool {
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return false
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return false
        }
        
        return true
    }
    
    private func generateMnemonic() {
        do {
            let mnemonicString = try HDKeyring.generateMnemonic()
            mnemonic = mnemonicString.components(separatedBy: " ")
        } catch {
            errorMessage = "Failed to generate mnemonic: \(error.localizedDescription)"
        }
    }
    
    private func prepareMnemonicVerification() {
        shuffledMnemonic = mnemonic.shuffled()
        selectedWords = []
    }
    
    private func selectWord(_ word: String) {
        selectedWords.append(word)
    }
    
    private func removeWord(at index: Int) {
        selectedWords.remove(at: index)
    }
    
    private func copyMnemonic() {
        UIPasteboard.general.string = mnemonic.joined(separator: " ")
    }
    
    private func createWallet() {
        guard selectedWords == mnemonic else {
            errorMessage = "Words are not in the correct order. Please try again."
            return
        }
        
        isCreating = true
        
        Task {
            do {
                // Create keyring with mnemonic
                let mnemonicString = mnemonic.joined(separator: " ")
                await keyringManager.createNewVault(password: password)
                
                let keyring = HDKeyring(mnemonic: mnemonicString)
                _ = try await keyring.addAccounts(count: 1)
                
                await keyringManager.addKeyring(keyring)
                
                // Save vault
                try await keyringManager.persistAllKeyrings()
                
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create wallet: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return password.count >= 8 && password == confirmPassword
        case 1:
            return !mnemonic.isEmpty
        case 2:
            return selectedWords.count == mnemonic.count
        default:
            return false
        }
    }
}

// MARK: - Password Strength View

struct PasswordStrengthView: View {
    let password: String
    
    var strength: Int {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil { score += 1 }
        return score
    }
    
    var strengthText: String {
        switch strength {
        case 0...1: return "Weak"
        case 2...3: return "Medium"
        case 4...5: return "Strong"
        default: return "Weak"
        }
    }
    
    var strengthColor: Color {
        switch strength {
        case 0...1: return .red
        case 2...3: return .orange
        case 4...5: return .green
        default: return .gray
        }
    }
    
    var body: some View {
        HStack {
            Text("Strength:")
                .font(.caption)
            
            Text(strengthText)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(strengthColor)
            
            Spacer()
            
            HStack(spacing: 4) {
                ForEach(0..<5) { index in
                    Rectangle()
                        .fill(index < strength ? strengthColor : Color(.systemGray5))
                        .frame(width: 40, height: 4)
                        .cornerRadius(2)
                }
            }
        }
    }
}

// MARK: - Flow Layout

@available(iOS 16.0, *)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.bounds
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var bounds = CGSize.zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            bounds = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

struct CreateWalletView_Previews: PreviewProvider {
    static var previews: some View {
        CreateWalletView()
    }
}
