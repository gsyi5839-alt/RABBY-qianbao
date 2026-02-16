import SwiftUI

/// View showing active WalletConnect sessions on the home page
/// Corresponds to: extension CurrentConnection display
struct WalletConnectSessionsView: View {
    @StateObject private var wcManager = WalletConnectManager.shared
    @State private var showDisconnectAlert = false
    @State private var sessionToDisconnect: WalletConnectManager.WCSession?
    
    var body: some View {
        List {
            if wcManager.sessions.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "link.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(L("No Active Connections"))
                            .font(.headline)
                        Text(L("Connect to dApps using WalletConnect"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(wcManager.sessions, id: \.topic) { session in
                        sessionRow(session)
                    }
                } header: {
                    HStack {
                        Text(L("Active Sessions"))
                        Spacer()
                        Text("\(wcManager.sessions.count)")
                            .font(.caption).fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        Task { await wcManager.disconnectAllSessions() }
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text(L("Disconnect All"))
                        }
                    }
                }
            }
        }
        .navigationTitle(L("DApp Connections"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(L("Disconnect"), isPresented: $showDisconnectAlert) {
            Button(L("Cancel"), role: .cancel) { }
            Button(L("Disconnect"), role: .destructive) {
                if let session = sessionToDisconnect {
                    Task {
                        await WalletConnectManager.shared.disconnectSession(session.id)
                    }
                }
            }
        } message: {
            Text(L("Are you sure you want to disconnect this session?"))
        }
        .onAppear {
            wcManager.refreshSessions()
        }
    }
    
    private func sessionRow(_ session: WalletConnectManager.WCSession) -> some View {
        HStack(spacing: 12) {
            // DApp icon
            if let iconURL = session.peerIcon, let url = URL(string: iconURL) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Circle().fill(Color(.systemGray5))
                        .overlay(Image(systemName: "globe").foregroundColor(.secondary))
                }
                .frame(width: 40, height: 40)
                .cornerRadius(10)
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "globe")
                            .foregroundColor(.secondary)
                    )
                    .cornerRadius(10)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.peerName)
                    .font(.subheadline).fontWeight(.medium)
                
                if !session.peerUrl.isEmpty {
                    Text(session.peerUrl)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Connected chains
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text(L("Connected"))
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Button(action: {
                sessionToDisconnect = session
                showDisconnectAlert = true
            }) {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
