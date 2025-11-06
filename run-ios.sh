#!/bin/bash

DEVICE_ID="00008101-001D79A60C89001E"
PROJECT="Places.xcodeproj"
SCHEME="places"
APP_NAME="places.app"

echo "Building for device..."

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -sdk iphoneos \
  build

echo "Finding .app for device build..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path "*Debug-iphoneos/$APP_NAME" | head -n 1)

echo "App Path: $APP_PATH"

echo "Installing to iPhone..."
ios-deploy --id $DEVICE_ID --bundle "$APP_PATH" --justlaunch
#!/bin/bash

DEVICE_ID="00008101-001D79A60C89001E"
APP_NAME="places.app"

echo "Cleaning & Building for physical device..."
xcodebuild \
  -project Places.xcodeproj \
  -scheme places \
  -configuration Debug \
  -sdk iphoneos \
  -destination "platform=iOS,id=$DEVICE_ID" \
  build

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Build/Products/Debug-iphoneos/$APP_NAME" | head -n 1)

echo "Installing & Launching on device..."
ios-deploy --id $DEVICE_ID --bundle "$APP_PATH"

