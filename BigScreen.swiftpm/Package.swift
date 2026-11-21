// swift-tools-version: 5.9

// This file is a Swift Playgrounds / Xcode "App" package.
// Open the BigScreen.swiftpm folder in Swift Playgrounds (iPad or Mac) or Xcode.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "BigScreen",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "BigScreen",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.bigscreen",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .tv),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
