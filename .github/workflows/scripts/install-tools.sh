#!/bin/bash

echo "::add-path::$HOME/.pub-cache/bin"
echo "::add-path::$GITHUB_WORKSPACE/_flutter/.pub-cache/bin"
echo "::add-path::$GITHUB_WORKSPACE/_flutter/bin/cache/dart-sdk/bin"
flutter doctor -v