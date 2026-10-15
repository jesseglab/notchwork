// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Notchwork", platforms: [.macOS(.v14)], products: [
    .library(name: "NotchworkKit", type: .static, targets: ["NotchworkKit"]),
    .executable(name: "Notchwork", targets: ["NotchworkHost"]),
    .executable(name: "notchworkctl", targets: ["notchworkctl"])
], targets: [
    .target(name: "NotchworkKit"),
    .executableTarget(name: "NotchworkHost", dependencies: ["NotchworkKit"]),
    .executableTarget(name: "notchworkctl", dependencies: ["NotchworkKit"]),
    .testTarget(name: "NotchworkKitTests", dependencies: ["NotchworkKit", "NotchworkHost"])
])
