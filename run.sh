cargo build --release

swiftc Swift/main.swift \
-L "$(pwd)/target/release" \
-l kiri \
-o kiri

./kiri
