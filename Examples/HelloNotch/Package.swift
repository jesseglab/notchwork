// swift-tools-version: 5.9
import PackageDescription
import Foundation
let package = Package(
    name: "HelloNotch", platforms: [.macOS(.v14)],
    dependencies: [.package(name: "notchwork", path: ProcessInfo.processInfo.environment["NOTCHWORK_PACKAGE_PATH"] ?? "../..")],
    targets: [.executableTarget(name: "HelloNotch", dependencies: [.product(name: "NotchworkKit", package: "notchwork")])]
)
