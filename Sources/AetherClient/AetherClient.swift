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
        routeBlock: String,
        routeDirect: String,
        localPort: String,
        httpProxy: String,
        dns: String,
        logLevel: String,
        perfLevel: String,
        teamName: String,
        accessEmail: String,
        enableGateway: Bool,
        wiwOuter: String,
        wiwInner: String
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
        
        if !routeBlock.isEmpty {
            args.append("--route-block")
            args.append(routeBlock)
        }
        
        if !routeDirect.isEmpty {
            args.append("--route-direct")
            args.append(routeDirect)
        }

        if !localPort.isEmpty && localPort != "1819" {
             args.append("--port")
             args.append(localPort)
        }
        
        if !httpProxy.isEmpty {
            args.append("--http-proxy")
            args.append(httpProxy)
        }
        
        if !dns.isEmpty {
            args.append("--dns")
            args.append(dns)
        }
        
        if logLevel != "info" {
            args.append("--log-level")
            args.append(logLevel)
        }
        
        if perfLevel != "auto" {
            args.append("--perf")
            args.append(perfLevel)
        }
        
        if !teamName.isEmpty {
            args.append("--team")
            args.append(teamName)
            if !accessEmail.isEmpty {
                args.append("--access-email")
                args.append(accessEmail)
            }
            if enableGateway {
                args.append("--gateway")
            }
        }
        
        if protocolName == "gool" {
            if !wiwOuter.isEmpty {
                args.append("--wiw-outer")
                args.append(wiwOuter)
            }
            if !wiwInner.isEmpty {
                args.append("--wiw-inner")
                args.append(wiwInner)
            }
        }
        
        logs += "Executing: ./aether \(args.joined(separator: " "))\n\n"
        
        var executablePath = ""
        var workingDirectory = ""
        
        if let resourcePath = Bundle.main.path(forResource: "aether", ofType: nil) {
            executablePath = resourcePath
            workingDirectory = Bundle.main.bundlePath + "/Contents/Resources"
        } else {
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
    @State private var routeBlock = ""
    @State private var routeDirect = ""
    @State private var localPort = "1819"
    @State private var httpProxy = ""
    @State private var dns = ""
    @State private var logLevel = "info"
    @State private var perfLevel = "auto"
    @State private var teamName = ""
    @State private var accessEmail = ""
    @State private var enableGateway = false
    @State private var wiwOuter = ""
    @State private var wiwInner = ""
    @State private var terminalInput = ""
    
    let protocols = ["masque", "wireguard", "gool"]
    let httpVersions = ["http3", "http2"]
    let scanModes = ["turbo", "balanced", "ironclad"]
    let noiseTypes = ["firewall", "light"]
    let logLevels = ["error", "warn", "info", "debug", "trace"]
    let perfLevels = ["auto", "low", "medium", "high"]
    
    var body: some View {
        HStack(spacing: 0) {
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Aether Settings")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                            Text("v1.9.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
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
                                
                                HStack {
                                    Text("HTTP Proxy:")
                                    TextField("127.0.0.1:8080", text: $httpProxy)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                                
                                HStack {
                                    Text("DNS:")
                                    TextField("1.1.1.1,8.8.8.8", text: $dns)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                            }
                            .padding(5)
                        }
                        
                        GroupBox("Obfuscation & Routing") {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("Obfuscation (Noise)", isOn: $enableNoise)
                                if enableNoise {
                                    Picker("Noise Type:", selection: $noiseType) {
                                        ForEach(noiseTypes, id: \.self) { Text($0.capitalized).tag($0) }
                                    }
                                }
                                
                                Text("Upstream Proxy:")
                                    .font(.caption)
                                TextField("socks5://...", text: $upstreamProxy)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Text("Route Block:")
                                    .font(.caption)
                                TextField("domain:ads.example.com", text: $routeBlock)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Text("Route Direct:")
                                    .font(.caption)
                                TextField("iran:direct", text: $routeDirect)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .padding(5)
                        }
                        
                        GroupBox("Zero Trust") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Team:")
                                    TextField("org-name", text: $teamName)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                                
                                if !teamName.isEmpty {
                                    HStack {
                                        Text("Email:")
                                        TextField("user@example.com", text: $accessEmail)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }
                                    Toggle("Gateway Proxy", isOn: $enableGateway)
                                }
                            }
                            .padding(5)
                        }
                        
                        if selectedProtocol == "gool" {
                            GroupBox("WiW Peers") {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("Outer:")
                                        TextField("162.159.192.1:2408", text: $wiwOuter)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }
                                    HStack {
                                        Text("Inner:")
                                        TextField("188.114.96.1:2408", text: $wiwInner)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }
                                }
                                .padding(5)
                            }
                        }
                        
                        GroupBox("Diagnostics") {
                            VStack(alignment: .leading, spacing: 10) {
                                Picker("Log Level:", selection: $logLevel) {
                                    ForEach(logLevels, id: \.self) { Text($0.capitalized).tag($0) }
                                }
                                Picker("Performance:", selection: $perfLevel) {
                                    ForEach(perfLevels, id: \.self) { Text($0.capitalized).tag($0) }
                                }
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
                                    routeBlock: routeBlock,
                                    routeDirect: routeDirect,
                                    localPort: localPort,
                                    httpProxy: httpProxy,
                                    dns: dns,
                                    logLevel: logLevel,
                                    perfLevel: perfLevel,
                                    teamName: teamName,
                                    accessEmail: accessEmail,
                                    enableGateway: enableGateway,
                                    wiwOuter: wiwOuter,
                                    wiwInner: wiwInner
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
        .frame(width: 900, height: 700)
    }
}
