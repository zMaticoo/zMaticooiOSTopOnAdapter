// swift-tools-version:5.3
//
// 只声明 zMaticoo。AnyThinkiOS / TPNiOS 无官方 SPM，由宿主自行接入
//（手动 xcframework 或 CocoaPods），且必须加到同一个 App target。
// 模块名仍是 AnyThinkSDK（TPN 也一样）。
//
// 两个 product 对应 CocoaPods Latest / Legacy，类名相同，宿主只勾一个。
// AnyThink vs TPN 不再拆 product：源码相同，差别只在宿主接哪套二进制。
//
import PackageDescription

let package = Package(
    name: "TopOnzMaticooAdapter",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "TopOnzMaticooAdapter",
            targets: ["TopOnzMaticooAdapter"]
        ),
        .library(
            name: "TopOnzMaticooAdapterLegacy",
            targets: ["TopOnzMaticooAdapterLegacy"]
        )
    ],
    dependencies: [
        .package(name: "zMaticoo", url: "https://github.com/cloudadrd/zMaticooPodSpec.git", from: "2.3.1")
    ],
    targets: [
        .target(
            name: "TopOnzMaticooAdapter",
            dependencies: [
                .product(name: "MaticooSDK", package: "zMaticoo")
            ],
            path: "Classes",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath(".")
            ]
        ),
        .target(
            name: "TopOnzMaticooAdapterLegacy",
            dependencies: [
                .product(name: "MaticooSDK", package: "zMaticoo")
            ],
            path: "ClassesLegacy",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath(".")
            ]
        )
    ]
)
