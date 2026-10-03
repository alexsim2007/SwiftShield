#!/bin/sh
set -eu

SING_BOX_REPOSITORY="https://github.com/SagerNet/sing-box.git"
SING_BOX_COMMIT="2ff3985c0a8fd628ab10b9ec9cd3d37512909c57"
GOMOBILE_VERSION="v0.1.13"

ROOT_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIRECTORY="$ROOT_DIRECTORY/.vendor-build/sing-box"
OUTPUT_DIRECTORY="$ROOT_DIRECTORY/Vendor/Libbox.xcframework"

if ! command -v go >/dev/null 2>&1; then
    echo "Go is required. Install it with: brew install go" >&2
    exit 1
fi

GOPATH=$(go env GOPATH)
PATH="$GOPATH/bin:$PATH"
export PATH
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

go install "github.com/sagernet/gomobile/cmd/gomobile@$GOMOBILE_VERSION"
go install "github.com/sagernet/gomobile/cmd/gobind@$GOMOBILE_VERSION"
gomobile init

mkdir -p "$(dirname -- "$BUILD_DIRECTORY")" "$(dirname -- "$OUTPUT_DIRECTORY")"
if [ ! -d "$BUILD_DIRECTORY/.git" ]; then
    git clone "$SING_BOX_REPOSITORY" "$BUILD_DIRECTORY"
fi

git -C "$BUILD_DIRECTORY" fetch origin "$SING_BOX_COMMIT"
git -C "$BUILD_DIRECTORY" checkout --detach "$SING_BOX_COMMIT"

(
    cd "$BUILD_DIRECTORY"
    go run ./cmd/internal/build_libbox -target apple -platform ios,iossimulator
)

if [ -e "$OUTPUT_DIRECTORY" ]; then
    mv "$OUTPUT_DIRECTORY" "$OUTPUT_DIRECTORY.previous"
fi
ditto "$BUILD_DIRECTORY/Libbox.xcframework" "$OUTPUT_DIRECTORY"
rm -rf "$OUTPUT_DIRECTORY.previous"

echo "Libbox is ready at $OUTPUT_DIRECTORY"
