// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScoutKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ScoutKit", targets: ["ScoutKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.48.0")
    ],
    targets: [
        .target(
            name: "ScoutKit",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ]
        )
    ]
)
