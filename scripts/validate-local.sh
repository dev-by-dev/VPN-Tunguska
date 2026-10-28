#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

swift build --target TunguskaCore
swift build --target Tunguska
swift build --target TunguskaHelper
swift build --target TunguskaTunnel
swift test
swift run TunguskaCoreCheck
