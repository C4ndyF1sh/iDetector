//
//  ContentView.swift
//  iDetector
//  iChecker
//
//  Created by Candy on 20.05.25.
//

import SwiftUI
import Foundation
import UIKit

struct ContentView: View {
    @State private var bundleID: String = ""
    @State private var filePath: String = ""
    @State private var isInstalled: Bool? = nil
    @State private var isValidPath: Bool? = nil
    @State private var logs: [String] = []
    @State private var testedBundleIDs: [(id: String, success: Bool)] = []
    @State private var testedPaths: [(path: String, success: Bool)] = []

    @AppStorage("launchCheckEnabled") private var launchCheckEnabled: Bool = false
    @AppStorage("launchCheckBundleID") private var launchCheckBundleID: String = ""
    @AppStorage("launchCheckFileEnabled") private var launchCheckFileEnabled: Bool = false
    @AppStorage("launchCheckFilePath") private var launchCheckFilePath: String = ""

    private let historyKey = "TestedBundleIDsHistory"
    private let pathHistoryKey = "TestedPathsHistory"

    var body: some View {
        TabView {
            checkerView
                .tabItem {
                    Label("Checker", systemImage: "magnifyingglass")
                }
            
            historyView
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            
            settingsView
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .onAppear {
            loadHistory()
            loadPathHistory()
            if launchCheckEnabled, !launchCheckBundleID.isEmpty {
                logs.append("[*] Launch Check: \(launchCheckBundleID)")
                let result = Self.checkApp(bundleID: launchCheckBundleID, log: { logs.append($0) })
                isInstalled = result
                testedBundleIDs.append((launchCheckBundleID, result))
                saveHistory()
            }
            if launchCheckFileEnabled, !launchCheckFilePath.isEmpty {
                let result = checkPathExists(path: launchCheckFilePath)
                isValidPath = result    // <--- add this line to update UI
                logs.append("[*] Launch File Check: \(launchCheckFilePath): \(result ? "✅ Exists" : "❌ Not found")")
                testedPaths.append((launchCheckFilePath, result))
                savePathHistory()
            }
        }
    }

    var checkerView: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    GroupBox(label: Label("Bundle ID Existence Checker (<18.4.1)", systemImage: "app.badge")) {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("e.g. com.apple.tips", text: $bundleID)
                                .textFieldStyle(.roundedBorder)

                            Button(action: {
                                guard !bundleID.isEmpty else { return }
                                logs.append("[*] Checking Bundle ID: \(bundleID)")
                                let result = Self.checkApp(bundleID: bundleID, log: { logs.append($0) })
                                isInstalled = result
                                testedBundleIDs.append((bundleID, result))
                                saveHistory()
                            }) {
                                Label("Check App", systemImage: "checkmark.shield")
                                    .frame(maxWidth: .infinity)
                            }
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)

                            if let installed = isInstalled {
                                HStack {
                                    Image(systemName: installed ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                        .foregroundColor(installed ? .green : .red)
                                    Text(installed ? "App is installed" : "App is not installed")
                                        .foregroundColor(installed ? .green : .red)
                                        .bold()
                                }
                            }
                        }
                        .padding(.vertical, 5)
                    }

                    GroupBox(label: Label("Path Existence Checker (<18.5)", systemImage: "folder.fill")) {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("e.g. /var/mobile/Containers/Shared/AppGroup/...", text: $filePath)
                                .textFieldStyle(.roundedBorder)

                            Button(action: {
                                logs.append("[*] Initiating path existence check...")
                                logs.append("[*] Using FileManager.default.fileExists(atPath:) API")
                                logs.append("[*] Checking path: \(filePath)")

                                let fileManager = FileManager.default
                                var isDir: ObjCBool = false
                                let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDir)

                                logs.append("[*] FileManager.fileExists returned: \(exists ? "true" : "false")")

                                if exists {
                                    logs.append("[*] Path exists: \(filePath)")
                                    logs.append("[*] Detected as \(isDir.boolValue ? "directory" : "file")")
                                    isValidPath = true
                                } else {
                                    logs.append("[*] Path does NOT exist: \(filePath)")
                                    isValidPath = false
                                }

                                logs.append("[*] Path existence check complete.")
                                testedPaths.append((filePath, isValidPath == true))
                                savePathHistory()
                            })
                            {
                                Label("Check Path", systemImage: "doc.text.magnifyingglass")
                                    .frame(maxWidth: .infinity)
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)

                            if let valid = isValidPath {
                                HStack {
                                    Image(systemName: valid ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                        .foregroundColor(valid ? .green : .red)
                                    Text(valid ? "Path exists" : "Path does not exist")
                                        .foregroundColor(valid ? .green : .red)
                                        .bold()
                                }
                            }
                        }
                        .padding(.vertical, 5)
                    }

                    GroupBox(label: Label("Logs", systemImage: "terminal")) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(logs, id: \.self) { log in
                                    Text(log)
                                        .font(.caption.monospaced())
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding()
                        }
                        .frame(height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    VStack(spacing: 4) {
                        Link("Get System App Bundle IDs (iOS/iPadOS 18+ might not have all)", destination: URL(string: "https://github.com/joeblau/apple-bundle-identifiers")!)
                            .font(.footnote)

                        Link("Get App Store Bundle IDs", destination: URL(string: "https://vexelon.net/asws")!)
                            .font(.footnote)
                    }
                }
                .padding()
            }
            .navigationTitle("iChecker")
        }
    }

    var historyView: some View {
        NavigationView {
            List {
                let appleBundleIDs = testedBundleIDs.enumerated().filter { $0.element.id.contains("apple") }
                let otherBundleIDs = testedBundleIDs.enumerated().filter { !$0.element.id.contains("apple") }

                if appleBundleIDs.isEmpty && otherBundleIDs.isEmpty && testedPaths.isEmpty {
                    Text("No history available yet.")
                        .foregroundColor(.gray)
                } else {
                    if !appleBundleIDs.isEmpty {
                        Section(header: Text("Apple Bundle IDs")) {
                            ForEach(appleBundleIDs, id: \ .element.id) { index, entry in
                                HStack {
                                    Text(entry.id)
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                    Text(entry.success ? "✅" : "❌")
                                        .foregroundColor(entry.success ? .green : .red)
                                }
                            }
                            .onDelete { offsets in
                                let trueOffsets = offsets.map { appleBundleIDs[$0].offset }
                                deleteHistory(at: IndexSet(trueOffsets))
                            }
                        }
                    }

                    if !otherBundleIDs.isEmpty {
                        Section(header: Text("Other Bundle IDs")) {
                            ForEach(otherBundleIDs, id: \ .element.id) { index, entry in
                                HStack {
                                    Text(entry.id)
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                    Text(entry.success ? "✅" : "❌")
                                        .foregroundColor(entry.success ? .green : .red)
                                }
                            }
                            .onDelete { offsets in
                                let trueOffsets = offsets.map { otherBundleIDs[$0].offset }
                                deleteHistory(at: IndexSet(trueOffsets))
                            }
                        }
                    }

                    if !testedPaths.isEmpty {
                        Section(header: Text("Checked File Paths")) {
                            ForEach(testedPaths.indices, id: \ .self) { index in
                                let entry = testedPaths[index]
                                HStack {
                                    Text(entry.path)
                                        .font(.system(.body, design: .monospaced))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(entry.success ? "✅" : "❌")
                                        .foregroundColor(entry.success ? .green : .red)
                                }
                            }
                            .onDelete(perform: deletePathHistory)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear All") {
                        testedBundleIDs.removeAll()
                        testedPaths.removeAll()
                        saveHistory()
                        savePathHistory()
                    }
                }
            }
        }
    }

    var settingsView: some View {
        NavigationView {
            Form {
                Section(header: Text("App Info")) {
                    Text("iChecker")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Created by @c4ndyf1sh")
                        .font(.subheadline)

                    Text("App Version: 0.2.0")
                        .font(.subheadline)
                }

                Section(header: Text("Startup Check")) {
                    Toggle("Check Bundle ID on Launch", isOn: $launchCheckEnabled)
                    if launchCheckEnabled {
                        TextField("Bundle ID to Check", text: $launchCheckBundleID)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    Toggle("Check File Path on Launch", isOn: $launchCheckFileEnabled)
                    if launchCheckFileEnabled {
                        TextField("File Path to Check", text: $launchCheckFilePath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }

                Section {
                    Text("Powered by CVE-2025-31207\nby ingQi Shi (@Mas0nShi) & Duy Trần (@khanhduytran0)")
                        .font(.footnote)
                        .fontWeight(.bold)
                }
            }
            .navigationTitle("Settings")
        }
    }

    func saveHistory() {
        let encodableHistory = testedBundleIDs.map { ["id": $0.id, "success": $0.success] }
        UserDefaults.standard.set(encodableHistory, forKey: historyKey)
    }

    func loadHistory() {
        guard let saved = UserDefaults.standard.array(forKey: historyKey) as? [[String: Any]] else { return }
        testedBundleIDs = saved.compactMap {
            guard let id = $0["id"] as? String, let success = $0["success"] as? Bool else { return nil }
            return (id, success)
        }
    }

    func deleteHistory(at offsets: IndexSet) {
        testedBundleIDs.remove(atOffsets: offsets)
        saveHistory()
    }

    func savePathHistory() {
        let encodable = testedPaths.map { ["path": $0.path, "success": $0.success] }
        UserDefaults.standard.set(encodable, forKey: pathHistoryKey)
    }

    func loadPathHistory() {
        guard let saved = UserDefaults.standard.array(forKey: pathHistoryKey) as? [[String: Any]] else { return }
        testedPaths = saved.compactMap {
            guard let path = $0["path"] as? String, let success = $0["success"] as? Bool else { return nil }
            return (path, success)
        }
    }

    func deletePathHistory(at offsets: IndexSet) {
        testedPaths.remove(atOffsets: offsets)
        savePathHistory()
    }

    static func checkApp(bundleID: String, log: (String) -> Void) -> Bool {
        let keyBytes = Array("94826663".utf8)
        let realName = "SBSLaunchApplicationWithIdentifierAndURLAndLaunchOptions"
        let encrypted = realName.utf8.enumerated().map { idx, b in
            b ^ keyBytes[idx % keyBytes.count]
        }
        let decryptedBytes = encrypted.enumerated().map { idx, b in
            b ^ keyBytes[idx % keyBytes.count] } + [0]
        guard let fnName = String(bytes: decryptedBytes, encoding: .utf8) else {
            log("[*] Failed to use API SBSLaunchApplicationWithIdentifierAndURLAndLaunchOptions")
            return false
        }
        log("[*] Using API \(fnName)")

        guard let handle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW) else {
            log("[*] dlopen failed: \(String(cString: dlerror()))")
            return false
        }
        log("[*] Loaded SpringBoardServices")

        guard let sym = dlsym(handle, fnName) else {
            log("[*] dlsym error: \(String(cString: dlerror()))")
            dlclose(handle)
            return false
        }
        log("[*] Symbol resolved")

        typealias SBSLaunchFn = @convention(c) (CFString, CFURL?, CFDictionary, CFDictionary) -> Int32
        let launcher = unsafeBitCast(sym, to: SBSLaunchFn.self)

        let result = launcher(bundleID as CFString, nil, NSDictionary(), NSDictionary())
        log("[*] API returned code: \(result)")

        dlclose(handle)

        switch result {
        case 9: return true
        case 7: return false
        default:
            log("[*] Unexpected code; assuming not installed")
            return false
        }
    }

    func checkPathExists(path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}

#Preview {
    ContentView()
}
