// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "ChannelZ",
    products: [
        .library(name: "ChannelZ", targets: ["ChannelZ"]),
        ],
    targets: [
        .target(name: "ChannelZ"),
        .testTarget(name: "ChannelZTests"),
        ]
)
