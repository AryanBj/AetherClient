import SwiftUI
import Foundation

@main
struct AetherClientApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AetherManager: @unchecked Sendable, ObservableObject {
    @Published var logs: String = "Ready to connect...\n"
    @Published var isRunning: Bool = false
    
    private var process: Process?
    private var outPipe: Pipe?
    private var inPipe: Pipe?
    
    func start(
        protocolName: String,
        httpVersion: String,
        scanMode: String,
        useIPv4: Bool,
        useIPv6: Bool,
        enableNoise: Bool,
        noiseType: String,
        upstream: String,
        routing: String,
        localPort: String
    ) {
        guard !isRunning else { return }
        
        logs = "Preparing configurations...\n"
        var args: [String] = []
        
        if protocolName == "masque" {
            args.append("--masque")
            if httpVersion == "http2" { args.append("--http2") }
        } else if protocolName == "wireguard" {
            args.append("--wireguard")
        } else if protocolName == "gool" {
            args.append("--gool")
        }
        
        if useIPv4 { args.append("-4") }
        if useIPv6 { args.append("-6") }
        
        args.append("--scan")
        args.append(scanMode)
        
        if enableNoise {
            args.append("--noize")
            args.append(noiseType.isEmpty ? "firewall" : noiseType)
        }
        
        if !upstream.isEmpty {
            args.append("--upstream")
            args.append(upstream)
        }
        
        if !routing.isEmpty {
            args.append("--route")
            args.append(routing)
        }

        if !localPort.isEmpty && localPort != "1819" {
             args.append("--port")
             args.append(localPort)
        }
        
        logs += "Executing: ./aether \(args.joined(separator: " "))\n\n"
        
        var executablePath = ""
        var workingDirectory = ""
        
        // مسیر داینامیک: بررسی میکنه که آیا فایل داخل پکیج .app هست یا نه
        if let resourcePath = Bundle.main.path(forResource: "aether", ofType: nil) {
            executablePath = resourcePath
            workingDirectory = Bundle.main.bundlePath + "/Contents/Resources"
        } else {
            // مسیر موقت برای اجرای مستقیم از ترمینال
            executablePath = "/Users/aryan/Downloads/aether/aether"
            workingDirectory = "/Users/aryan/Downloads/aether"
        }
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: executablePath)
        process?.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        process?.arguments = args
        
        outPipe = Pipe()
        inPipe = Pipe()
        
        process?.standardOutput = outPipe
        process?.standardError = outPipe
        process?.standardInput = inPipe
        
        outPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.logs += output
                }
            }
        }
        
        process?.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.logs += "\n[System] Process terminated.\n"
            }
        }
        
        do {
            try process?.run()
            isRunning = true
        } catch {
            logs += "Execution Error: \(error.localizedDescription)\n"
            isRunning = false
        }
    }
    
    func sendInput(_ text: String) {
        guard isRunning, let inPipe = inPipe else { return }
        let inputString = text + "\n"
        if let data = inputString.data(using: .utf8) {
            try? inPipe.fileHandleForWriting.write(contentsOf: data)
            logs += "> \(text)\n"
        }
    }
    
    func stop() {
        process?.terminate()
        isRunning = false
    }
}

struct ContentView: View {
    @StateObject private var manager = AetherManager()
    
    @State private var selectedProtocol = "masque"
    @State private var selectedHTTPVersion = "http3"
    @State private var selectedScan = "turbo"
    @State private var useIPv4 = true
    @State private var useIPv6 = false
    @State private var enableNoise = false
    @State private var noiseType = "firewall"
    @State private var upstreamProxy = ""
    @State private var routingRules = ""
    @State private var localPort = "1819"
    @State private var terminalInput = ""
    
    let protocols = ["masque", "wireguard", "gool"]
    let httpVersions = ["http3", "http2"]
    let scanModes = ["turbo", "balanced"]
    
    var body: some View {
        HStack(spacing: 0) {
            // پنل تنظیمات
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Aether Settings")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        GroupBox("Protocol & Scan") {
                            VStack(alignment: .leading, spacing: 10) {
                                Picker("Protocol:", selection: $selectedProtocol) {
                                    ForEach(protocols, id: \.self) { Text($0.uppercased()).tag($0) }
                                }
                                
                                if selectedProtocol == "masque" {
                                    Picker("HTTP Ver:", selection: $selectedHTTPVersion) {
                                        ForEach(httpVersions, id: \.self) { Text($0.uppercased()).tag($0) }
                                    }
                                }
                                
                                Picker("Scan Mode:", selection: $selectedScan) {
                                    ForEach(scanModes, id: \.self) { Text($0.capitalized).tag($0) }
                                }
                            }
                            .padding(5)
                        }
                        
                        GroupBox("Network & IP") {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("IPv4 Only (-4)", isOn: $useIPv4)
                                Toggle("IPv6 Only (-6)", isOn: $useIPv6)
                                
                                HStack {
                                    Text("Local Port:")
                                    TextField("1819", text: $localPort)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 80)
                                }
                            }
                            .padding(5)
                        }
                        
                        GroupBox("Advanced") {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("Obfuscation (Noise)", isOn: $enableNoise)
                                if enableNoise {
                                    TextField("Noise Type (e.g. firewall)", text: $noiseType)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                                
                                Text("Upstream Proxy:")
                                    .font(.caption)
                                TextField("socks5://...", text: $upstreamProxy)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Text("Routing:")
                                    .font(.caption)
                                TextField("iran:direct", text: $routingRules)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .padding(5)
                        }
                        
                        Spacer(minLength: 20)
                        
                        Button(action: {
                            if manager.isRunning {
                                manager.stop()
                            } else {
                                manager.start(
                                    protocolName: selectedProtocol,
                                    httpVersion: selectedHTTPVersion,
                                    scanMode: selectedScan,
                                    useIPv4: useIPv4,
                                    useIPv6: useIPv6,
                                    enableNoise: enableNoise,
                                    noiseType: noiseType,
                                    upstream: upstreamProxy,
                                    routing: routingRules,
                                    localPort: localPort
                                )
                            }
                        }) {
                            Text(manager.isRunning ? "Disconnect" : "Connect")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(manager.isRunning ? Color.red : Color.blue)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                }
                
                // بخش اطلاعات شما در پایین پنل تنظیمات
                VStack(spacing: 5) {
                    Text("Developed by Aryan")
                        .font(.footnote)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        Link("GitHub", destination: URL(string: "https://github.com/AryanBj")!)
                        Text("•")
                        Link("Telegram", destination: URL(string: "https://t.me/aryanbj")!)
                        Text("•")
                        Link("X", destination: URL(string: "https://x.com/aryan_bj")!)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.bottom, 15)
            }
            .frame(width: 320)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // پنل لاگ‌ها
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Terminal Logs (Proxy at 127.0.0.1:\(localPort.isEmpty ? "1819" : localPort))")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                
                ScrollView {
                    Text(manager.logs)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Color.black)
                .foregroundColor(.green)
                
                HStack {
                    TextField("Enter interactive command (e.g., y/n)...", text: $terminalInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(!manager.isRunning)
                        .onSubmit {
                            if !terminalInput.isEmpty {
                                manager.sendInput(terminalInput)
                                terminalInput = ""
                            }
                        }
                    
                    Button("Send") {
                        if !terminalInput.isEmpty {
                            manager.sendInput(terminalInput)
                            terminalInput = ""
                        }
                    }
                    .disabled(!manager.isRunning)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .frame(width: 900, height: 650)
    }
}