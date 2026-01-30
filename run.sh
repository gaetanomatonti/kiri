cargo build --release

swiftc main.swift \
-L "$(pwd)/target/release" \
-l kiri \
-o kiri

./kiri
