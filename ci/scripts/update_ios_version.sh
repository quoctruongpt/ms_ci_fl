#!/bin/bash

# Kiểm tra xem đã cung cấp version mới chưa
if [ -z "$1" ]; then
  echo "Lỗi: Vui lòng cung cấp version name mới"
  echo "Cách sử dụng: ./update_ios_version.sh <new_version_name>"
  echo "Ví dụ: ./update_ios_version.sh 1.0.0"
  exit 1
fi

NEW_VERSION="$1"
FLUTTER_PROJECT_PATH="$(pwd)/src/flutter_project"
IOS_PATH="$FLUTTER_PROJECT_PATH/ios"

# Kiểm tra thư mục iOS có tồn tại không
if [ ! -d "$IOS_PATH" ]; then
  echo "Lỗi: Không tìm thấy thư mục iOS tại $IOS_PATH"
  exit 1
fi

echo "=== Bắt đầu cập nhật version name iOS ==="
echo "Version mới: $NEW_VERSION"
echo "Đường dẫn thư mục iOS: $IOS_PATH"

# Di chuyển đến thư mục iOS
cd "$IOS_PATH" || exit 1

# Kiểm tra fastlane đã được cài đặt chưa
if ! command -v fastlane &> /dev/null; then
  echo "Lỗi: fastlane chưa được cài đặt"
  echo "Vui lòng cài đặt fastlane: gem install fastlane"
  exit 1
fi

# Hiển thị version hiện tại
echo "Version hiện tại:"
fastlane get_version

# Cập nhật version sử dụng fastlane
echo "Đang cập nhật version name iOS sang $NEW_VERSION..."
fastlane update_version_name version:"$NEW_VERSION"

echo "=== Cập nhật version name iOS hoàn tất ==="
