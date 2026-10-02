// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LoginCLITest",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.12.2")
    ],
    targets: [
        .executableTarget(
            name: "LoginCLITest",
            dependencies: ["Alamofire"]
        )
    ]
)
