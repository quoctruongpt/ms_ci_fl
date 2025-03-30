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
  
  # Sao chép APK vào thư mục artifacts
  local apk_path="${FLUTTER_PROJECT_DIR}/build/app/outputs/flutter-apk/app-${build_mode}.apk"
  local target_path="${ARTIFACTS_DIR}/app-${build_mode}.apk"
  
  cp "$apk_path" "$target_path"
  
  echo -e "${GREEN}Đã build APK thành công: $target_path${NC}"
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
  
  # Sao chép AAB vào thư mục artifacts
  local aab_path="${FLUTTER_PROJECT_DIR}/build/app/outputs/bundle/${build_mode}/app-${build_mode}.aab"
  local target_path="${ARTIFACTS_DIR}/app-${build_mode}.aab"
  
  cp "$aab_path" "$target_path"
  
  echo -e "${GREEN}Đã build App Bundle thành công: $target_path${NC}"
  return 0
}

# Hàm build test
build_test() {
  echo -e "${YELLOW}Thực hiện build test (APK release)...${NC}"
  
  # Clean dự án
  clean_flutter_project || return 1
  
  # Build release APK
  build_apk "release" || return 1
  
  echo -e "${GREEN}[OK] Build test thành công.${NC}"
  echo -e "${GREEN}[OK] APK được lưu tại: ${ARTIFACTS_DIR}/app-release.apk${NC}"
  
  return 0
}

# Hàm build release
build_release() {
  echo -e "${YELLOW}Thực hiện build release (release APK và AAB)...${NC}"
  
  # Clean dự án
  clean_flutter_project || return 1
  
  # Build release APK
  build_apk "release" || return 1
  
  # Build release AAB
  build_aab "release" || return 1
  
  echo -e "${GREEN}[OK] Build release thành công.${NC}"
  echo -e "${GREEN}[OK] APK được lưu tại: ${ARTIFACTS_DIR}/app-release.apk${NC}"
  echo -e "${GREEN}[OK] AAB được lưu tại: ${ARTIFACTS_DIR}/app-release.aab${NC}"
  
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
  
  # Thực hiện build theo tùy chọn
  if [[ "$build_type" == "test" ]]; then
    build_test || return 1
  else
    build_release || return 1
  fi
  
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