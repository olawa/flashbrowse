import SwiftUI

public struct AddSSHHostView: View {
    @ObservedObject var sshService = SSHService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var alias: String = ""
    @State private var hostName: String = ""
    @State private var user: String = ""
    @State private var port: Int = 22
    @State private var keyPath: String = ""
    @State private var initialDirectory: String = "~"
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(Color(red: 0.91, green: 0.33, blue: 0.13))
                    .font(.system(size: 16))
                Text("Add SSH Connection")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 10) {
                HStack {
                    Text("Alias / Name:")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 110, alignment: .trailing)
                    TextField("e.g. gpu-cluster", text: $alias)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("Hostname / IP:")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 110, alignment: .trailing)
                    TextField("e.g. 192.168.1.100 or hpc.uni.edu", text: $hostName)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("Username:")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 110, alignment: .trailing)
                    TextField("e.g. ubuntu or user", text: $user)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("Port:")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 110, alignment: .trailing)
                    TextField("22", value: $port, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Spacer()
                }
                
                HStack {
                    Text("SSH Key (opt):")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 110, alignment: .trailing)
                    TextField("~/.ssh/id_rsa or id_ed25519", text: $keyPath)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("Remote Path:")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 110, alignment: .trailing)
                    TextField("~", text: $initialDirectory)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save & Connect") {
                    saveAndConnect()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.91, green: 0.33, blue: 0.13))
                .disabled(alias.trimmingCharacters(in: .whitespaces).isEmpty || hostName.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
    
    private func saveAndConnect() {
        let cleanAlias = alias.trimmingCharacters(in: .whitespaces)
        let cleanHost = hostName.trimmingCharacters(in: .whitespaces)
        let cleanUser = user.trimmingCharacters(in: .whitespaces)
        let cleanKey = keyPath.trimmingCharacters(in: .whitespaces)
        let cleanDir = initialDirectory.trimmingCharacters(in: .whitespaces)
        
        let host = SSHHost(
            alias: cleanAlias,
            hostName: cleanHost,
            user: cleanUser,
            port: port,
            identityFile: cleanKey.isEmpty ? nil : cleanKey,
            initialDirectory: cleanDir.isEmpty ? "~" : cleanDir
        )
        
        sshService.saveCustomHost(host)
        sshService.connect(to: host)
        dismiss()
    }
}
