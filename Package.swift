// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GravityPaintStudio",
    // Target macOS 14 (Sonoma) or newer to ensure Metal 3 support for M4
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "GravityPaintStudio",
            targets: ["GravityPaintStudio"]
        )
    ],
    dependencies: [
        // Add dependencies here later if needed (e.g., for complex math)
    ],
    targets: [
        .executableTarget(
            name: "GravityPaintStudio",
            // IMPORTANT: We tell SPM to look in 'Sources' generally, 
            // allowing our custom subfolder structure (App, Physics, Shaders).
            path: "Sources",
            // We explicitly tell the compiler to process the Shaders folder
            // so the .metal files are compiled into a default.metallib
            resources: [
                .process("Shaders")
            ],
            swiftSettings: [
                // Enable strict concurrency to maximize M4's multi-core safety
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "GravityPaintStudioTests",
            dependencies: ["GravityPaintStudio"]
        )
    ]
)