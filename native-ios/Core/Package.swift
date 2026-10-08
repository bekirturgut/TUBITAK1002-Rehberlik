// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "RehberlikCore", platforms: [.iOS(.v16), .macOS(.v13)], products: [.library(name: "RehberlikCore", targets: ["RehberlikCore"])], targets: [.target(name: "RehberlikCore"), .testTarget(name: "RehberlikCoreTests", dependencies: ["RehberlikCore"])])
