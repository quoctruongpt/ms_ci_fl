#!/bin/bash

# Script build ứng dụng Flutter cho Android
# ========================================

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Xác định đường dẫn gốc nếu chưa được truyền vào
if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
fi

# Đường dẫn đến dự án Flutter
FLUTTER_PROJECT_DIR="${ROOT_DIR}/src/flutter_project"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/android"

# Hàm clean dự án Flutter
clean_flutter_project() {
  echo -e "${YELLOW}Đang clean dự án Flutter...${NC}"
  cd "$FLUTTER_PROJECT_DIR"
  flutter clean
  flutter pub get
  if [[ $? -ne 0 ]]; then
    echo -e "${RED}[LỖI] Không thể clean và pub get dự án Flutter${NC}"
    return 1
  fi
  echo -e "${GREEN}Đã clean dự án Flutter thành công.${NC}"
  return 0
}

# Hàm upload build lên server
upload_build() {
  local file_path="$1"
  local build_type="$2"
  local platform="$3"
  
  echo -e "${YELLOW}Đang upload file build lên server...${NC}"
  
  # Kiểm tra file tồn tại
  if [[ ! -f "$file_path" ]]; then
    echo -e "${RED}[LỖI] Không tìm thấy file build tại: $file_path${NC}"
    return 1
  fi
  
  # Lấy tên file
  local file_name=$(basename "$file_path")
  
  # Upload file lên Monkey Media
  local response=$(curl -s -X POST \
    --location 'https://media.monkeyuni.net/api/upload' \
    --header 'token: a813ec766197294184a938c331b08e7e' \
    --form "file=@\"$file_path\"" \
    --form 'description=""' \
    --form 'folder_path="CI_MS"' \
    --form 'bucket="monkeymedia2020"')
  
  # Kiểm tra kết quả upload
  if [[ $? -ne 0 ]]; then
    echo -e "${RED}[LỖI] Upload file thất bại.${NC}"
    return 1
  fi
  
  # Parse response để lấy URL tải (response có dạng JSON với field link)
  local download_url=$(echo "$response" | grep -o '"link":"[^"]*"' | cut -d'"' -f4 | sed 's/\\\//\//g')
  
  if [[ -z "$download_url" ]]; then
    echo -e "${RED}[LỖI] Không thể lấy URL tải từ response.${NC}"
    echo -e "${RED}Response: $response${NC}"
    return 1
  fi
  
  echo -e "${GREEN}[OK] Upload file thành công.${NC}"
  
  # Trả về URL tải mà không in ra console
  echo "$download_url"
  return 0
}

# Hàm build APK
build_apk() {
  local build_mode="$1" # debug, profile hoặc release
  
  echo -e "${YELLOW}Đang build APK (${build_mode})...${NC}"
  cd "$FLUTTER_PROJECT_DIR"
  
  # Tạo thư mục artifacts nếu chưa tồn tại
  mkdir -p "$ARTIFACTS_DIR"
  
  # Build APK
  flutter build apk --$build_mode
  
  # Kiểm tra kết quả
  if [[ $? -ne 0 ]]; then
    echo -e "${RED}[LỖI] Build APK thất bại.${NC}"
    return 1
  fi
  
  # Tạo timestamp
  local timestamp=$(date +"%Y%m%d_%H%M%S")
  
  # Sao chép APK vào thư mục artifacts với tên mới
  local apk_path="${FLUTTER_PROJECT_DIR}/build/app/outputs/flutter-apk/app-${build_mode}.apk"
  local target_path="${ARTIFACTS_DIR}/app-${build_mode}_${timestamp}.apk"
  
  cp "$apk_path" "$target_path"
  
  echo -e "${GREEN}Đã build APK thành công: $target_path${NC}"
  
  # Upload file build và lấy URL
  local download_url=$(upload_build "$target_path" "$build_mode" "android")
  
  # Trả về URL
  echo "$download_url"
  return 0
}

# Hàm build App Bundle (AAB)
build_aab() {
  local build_mode="$1" # release
  
  echo -e "${YELLOW}Đang build App Bundle (${build_mode})...${NC}"
  cd "$FLUTTER_PROJECT_DIR"
  
  # Tạo thư mục artifacts nếu chưa tồn tại
  mkdir -p "$ARTIFACTS_DIR"
  
  # Build AAB
  flutter build appbundle --$build_mode
  
  # Kiểm tra kết quả
  if [[ $? -ne 0 ]]; then
    echo -e "${RED}[LỖI] Build App Bundle thất bại.${NC}"
    return 1
  fi
  
  # Tạo timestamp
  local timestamp=$(date +"%Y%m%d_%H%M%S")
  
  # Sao chép AAB vào thư mục artifacts với tên mới
  local aab_path="${FLUTTER_PROJECT_DIR}/build/app/outputs/bundle/${build_mode}/app-${build_mode}.aab"
  local target_path="${ARTIFACTS_DIR}/app-${build_mode}_${timestamp}.aab"
  
  cp "$aab_path" "$target_path"
  
  echo -e "${GREEN}Đã build App Bundle thành công: $target_path${NC}"
  
  # Upload file build và lấy URL
  local download_url=$(upload_build "$target_path" "$build_mode" "android")
  
  # Trả về URL
  echo "$download_url"
  return 0
}

# Hàm build test
build_test() {
  echo -e "${YELLOW}Thực hiện build test (APK release)...${NC}"
  
  # Clean dự án
  clean_flutter_project || return 1
  
  # Build release APK và lấy URL
  local download_url=""
  download_url=$(build_apk "release") || return 1
  
  echo -e "${GREEN}[OK] Build test thành công.${NC}"
  echo -e "${GREEN}[OK] APK được lưu tại: ${ARTIFACTS_DIR}/app-release.apk${NC}"
  
  # Trả về URL
  echo "$download_url"
  return 0
}

# Hàm build release
build_release() {
  echo -e "${YELLOW}Thực hiện build release (release APK và AAB)...${NC}"
  
  # Clean dự án
  clean_flutter_project || return 1
  
  # Build release APK và lấy URL
  local apk_url=""
  apk_url=$(build_apk "release") || return 1
  
  # Build release AAB và lấy URL
  local aab_url=""
  aab_url=$(build_aab "release") || return 1
  
  echo -e "${GREEN}[OK] Build release thành công.${NC}"
  echo -e "${GREEN}[OK] APK được lưu tại: ${ARTIFACTS_DIR}/app-release.apk${NC}"
  echo -e "${GREEN}[OK] AAB được lưu tại: ${ARTIFACTS_DIR}/app-release.aab${NC}"
  
  # Trả về cả 2 URL, phân cách bằng dấu |
  echo "${apk_url} | ${aab_url}"
  return 0
}

# Hàm chính
main() {
  local build_type="$1"
  
  # Kiểm tra xem dự án Flutter có tồn tại không
  if [[ ! -d "$FLUTTER_PROJECT_DIR" ]]; then
    echo -e "${RED}[LỖI] Không tìm thấy dự án Flutter tại: $FLUTTER_PROJECT_DIR${NC}"
    return 1
  fi
  
  # Kiểm tra xem tùy chọn build hợp lệ không
  if [[ "$build_type" != "test" && "$build_type" != "release" ]]; then
    echo -e "${RED}[LỖI] Tùy chọn build không hợp lệ: $build_type. Hãy chọn 'test' hoặc 'release'.${NC}"
    return 1
  fi
  
  # Thực hiện build theo tùy chọn và lấy URL
  local urls=""
  if [[ "$build_type" == "test" ]]; then
    urls=$(build_test) || return 1
  else
    urls=$(build_release) || return 1
  fi
  
  # Trả về URL(s)
  echo "$urls"
  return 0
}

# Kiểm tra xem script có được gọi trực tiếp không (không phải được source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Giá trị mặc định là build test
  BUILD_TYPE=${1:-"test"}
  
  # Hiển thị thông tin
  echo "=== BUILD FLUTTER ANDROID ==="
  echo "Loại build: $BUILD_TYPE"
  
  # Chạy hàm chính
  main "$BUILD_TYPE"
  exit $?
fi 