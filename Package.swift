// swift-tools-version: 6.0

import PackageDescription

// XCUITestKit links XCTest, which on Apple platforms vends the XCUI* automation
// types. It is meant to be added to an app's UI-test bundle and built with
// Xcode's toolchain (the open-source swift.org toolchain's XCTest does not
// include XCUIApplication/XCUIElement).
let package = Package(
  name: "XCUITestKit",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .watchOS(.v10),
    .visionOS(.v1)
  ],
  products: [
    .library(
      name: "XCUITestKit",
      targets: ["XCUITestKit"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3")
  ],
  targets: [
    .target(name: "XCUITestKit"),
    .testTarget(
      name: "XCUITestKitTests",
      dependencies: ["XCUITestKit"]
    )
  ],
  swiftLanguageModes: [.v5, .v6]
)
