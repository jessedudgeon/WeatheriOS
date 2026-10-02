// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeatherCore",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [.library(name: "WeatherCore", targets: ["WeatherCore"])],
    targets: [
        .target(name: "WeatherCore", path: "Shared/Core"),
        .testTarget(name: "WeatherCoreTests", dependencies: ["WeatherCore"], path: "CoreTests", resources: [.copy("Fixtures")])
    ]
)
