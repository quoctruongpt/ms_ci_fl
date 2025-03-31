#!/bin/bash

# Script kiểm tra môi trường Flutter
# ===================================

# Xác định màu cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Phiên bản Flutter yêu cầu (có thể linh hoạt với phiên bản mới hơn)
REQUIRED_FLUTTER_VERSION="3.10.0"

# Kiểm tra Flutter đã được cài đặt hay chưa
check_flutter_installed() {
  if command -v flutter &> /dev/null; then
    echo -e "${GREEN}[OK] Flutter được tìm thấy trong PATH.${NC}"
    return 0
  else
    echo -e "${RED}[LỖI] Flutter không được tìm thấy trong PATH. Hãy cài đặt Flutter và đảm bảo nó có trong PATH.${NC}"
    return 1
  fi
}

# Kiểm tra phiên bản Flutter
check_flutter_version() {
  echo -e "${YELLOW}Kiểm tra phiên bản Flutter...${NC}"
  
  # Lấy phiên bản Flutter hiện tại
  local flutter_version=$(flutter --version | head -1 | awk '{print $2}')
  
  echo "Phiên bản Flutter hiện tại: $flutter_version"
  echo "Phiên bản Flutter yêu cầu tối thiểu: $REQUIRED_FLUTTER_VERSION"
  
  # Tách phiên bản thành các phần
  local IFS="."
  read -ra CURRENT_VERSION <<< "$flutter_version"
  read -ra REQUIRED_VERSION <<< "$REQUIRED_FLUTTER_VERSION"
  
  # Kiểm tra phiên bản chính
  if [[ ${CURRENT_VERSION[0]} -gt ${REQUIRED_VERSION[0]} ]]; then
    echo -e "${GREEN}[OK] Phiên bản Flutter mới hơn phiên bản yêu cầu.${NC}"
    return 0
  elif [[ ${CURRENT_VERSION[0]} -eq ${REQUIRED_VERSION[0]} && ${CURRENT_VERSION[1]} -gt ${REQUIRED_VERSION[1]} ]]; then
    echo -e "${GREEN}[OK] Phiên bản Flutter mới hơn phiên bản yêu cầu.${NC}"
    return 0
  elif [[ ${CURRENT_VERSION[0]} -eq ${REQUIRED_VERSION[0]} && ${CURRENT_VERSION[1]} -eq ${REQUIRED_VERSION[1]} && ${CURRENT_VERSION[2]} -ge ${REQUIRED_VERSION[2]} ]]; then
    echo -e "${GREEN}[OK] Phiên bản Flutter phù hợp hoặc mới hơn.${NC}"
    return 0
  else
    echo -e "${YELLOW}[CẢNH BÁO] Phiên bản Flutter cũ hơn phiên bản yêu cầu.${NC}"
    echo -e "${YELLOW}Bạn có thể gặp vấn đề khi build. Hãy cân nhắc cài đặt Flutter $REQUIRED_FLUTTER_VERSION hoặc mới hơn.${NC}"
    return 2
  fi
}

# Kiểm tra Flutter doctor
check_flutter_doctor() {
  echo -e "${YELLOW}Chạy Flutter doctor để kiểm tra cấu hình...${NC}"
  
  # Chạy Flutter doctor
  flutter doctor -v
  
  # Kiểm tra xem có lỗi quan trọng nào không
  # Bỏ qua các lỗi liên quan đến Chrome hoặc thiết bị không kết nối
  if flutter doctor -v | grep -i "error" | grep -v "Cannot find Chrome" | grep -v "Error: Browsing on the local area network" | grep -v "Error: xcodebuild" | grep -v "waiting for device" > /dev/null; then
    echo -e "${RED}[LỖI] Flutter doctor phát hiện lỗi nghiêm trọng.${NC}"
    return 1
  elif flutter doctor -v | grep -i "android licenses not accepted" > /dev/null; then
    echo -e "${YELLOW}[CẢNH BÁO] Một số giấy phép Android chưa được chấp nhận. Chạy 'flutter doctor --android-licenses' để khắc phục.${NC}"
    return 2
  else
    echo -e "${GREEN}[OK] Flutter doctor không phát hiện vấn đề nghiêm trọng.${NC}"
    return 0
  fi
}

# Kiểm tra Flutter embed Unity plugin
check_flutter_embed_unity() {
  echo -e "${YELLOW}Kiểm tra flutter_embed_unity plugin...${NC}"
  
  # Kiểm tra xem flutter_embed_unity có trong pubspec.yaml của project không
  if [[ -f "$1/pubspec.yaml" ]]; then
    if grep -q "flutter_embed_unity:" "$1/pubspec.yaml"; then
      echo -e "${GREEN}[OK] flutter_embed_unity đã được thêm vào pubspec.yaml.${NC}"
      return 0
    else
      echo -e "${YELLOW}[CẢNH BÁO] flutter_embed_unity chưa được thêm vào pubspec.yaml.${NC}"
      echo -e "${YELLOW}Sẽ được tự động thêm trong quá trình build nếu cần.${NC}"
      return 2
    fi
  else
    echo -e "${RED}[LỖI] Không tìm thấy file pubspec.yaml.${NC}"
    return 1
  fi
}

# Kiểm tra môi trường iOS (chỉ trên macOS)
check_ios_environment() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}Kiểm tra môi trường iOS...${NC}"
    
    # Kiểm tra Xcode
    if xcode-select -p &> /dev/null; then
      echo -e "${GREEN}[OK] Xcode đã được cài đặt.${NC}"
    else
      echo -e "${RED}[LỖI] Xcode chưa được cài đặt.${NC}"
      return 1
    fi
    
    # Kiểm tra CocoaPods
    if command -v pod &> /dev/null; then
      echo -e "${GREEN}[OK] CocoaPods đã được cài đặt.${NC}"
      return 0
    else
      echo -e "${RED}[LỖI] CocoaPods chưa được cài đặt. Hãy cài đặt bằng lệnh: sudo gem install cocoapods${NC}"
      return 1
    fi
  else
    # Không phải macOS, bỏ qua kiểm tra iOS
    return 0
  fi
}

# Kiểm tra môi trường Android
check_android_environment() {
  echo -e "${YELLOW}Kiểm tra môi trường Android...${NC}"
  
  # Kiểm tra biến môi trường ANDROID_SDK_ROOT
  if [[ -z "$ANDROID_SDK_ROOT" ]]; then
    echo -e "${YELLOW}[CẢNH BÁO] Biến môi trường ANDROID_SDK_ROOT chưa được thiết lập.${NC}"
    
    # Thử đoán đường dẫn Android SDK
    if [[ "$OSTYPE" == "darwin"* ]]; then
      local possible_sdk_root="$HOME/Library/Android/sdk"
    else
      local possible_sdk_root="$HOME/Android/Sdk"
    fi
    
    if [[ -d "$possible_sdk_root" ]]; then
      echo -e "${YELLOW}[CẢNH BÁO] Tìm thấy Android SDK tại $possible_sdk_root.${NC}"
      echo -e "${YELLOW}Thiết lập ANDROID_SDK_ROOT=$possible_sdk_root${NC}"
      export ANDROID_SDK_ROOT="$possible_sdk_root"
    else
      echo -e "${RED}[LỖI] Không tìm thấy Android SDK.${NC}"
      return 1
    fi
  else
    echo -e "${GREEN}[OK] ANDROID_SDK_ROOT đã được thiết lập: $ANDROID_SDK_ROOT${NC}"
  fi
  
  # Kiểm tra Android SDK Platform-Tools
  if [[ -x "$ANDROID_SDK_ROOT/platform-tools/adb" ]]; then
    echo -e "${GREEN}[OK] Android SDK Platform-Tools đã được cài đặt.${NC}"
    return 0
  else
    echo -e "${RED}[LỖI] Android SDK Platform-Tools chưa được cài đặt hoặc không tìm thấy.${NC}"
    return 1
  fi
}

# Hàm chính
main() {
  local flutter_project_dir="${1:-$PWD/src/flutter_project}"
  
  echo "=== KIỂM TRA MÔI TRƯỜNG FLUTTER ==="
  
  # Kiểm tra Flutter đã cài đặt chưa
  check_flutter_installed
  if [[ $? -ne 0 ]]; then
    echo -e "${RED}=== KIỂM TRA FLUTTER THẤT BẠI ===${NC}"
    exit 1
  fi
  
  # Kiểm tra phiên bản Flutter (cảnh báo nếu phiên bản không khớp)
  check_flutter_version
  local version_status=$?
  
  # Kiểm tra cấu hình Flutter (bỏ qua các lỗi không quan trọng)
  check_flutter_doctor
  local doctor_status=$?
  
  # Kiểm tra Flutter embed Unity plugin (không quan trọng)
  check_flutter_embed_unity "$flutter_project_dir"
  local plugin_status=$?
  
  # Kiểm tra môi trường nền tảng
  check_ios_environment
  local ios_status=$?
  
  check_android_environment
  local android_status=$?
  
  # Tổng hợp kết quả
  echo -e "${YELLOW}Tổng hợp kết quả kiểm tra:${NC}"
  echo "- Flutter được cài đặt: OK"
  echo "- Phiên bản Flutter: $([ $version_status -eq 0 ] && echo 'OK' || echo 'CẢNH BÁO')"
  echo "- Flutter doctor: $([ $doctor_status -eq 0 ] && echo 'OK' || [ $doctor_status -eq 2 ] && echo 'CẢNH BÁO' || echo 'LỖI')"
  echo "- Flutter embed Unity: $([ $plugin_status -eq 0 ] && echo 'OK' || [ $plugin_status -eq 2 ] && echo 'CẢNH BÁO' || echo 'LỖI')"
  echo "- Môi trường iOS: $([ $ios_status -eq 0 ] && echo 'OK' || echo 'LỖI')"
  echo "- Môi trường Android: $([ $android_status -eq 0 ] && echo 'OK' || echo 'LỖI')"
  
  # Điều kiện thành công: Flutter đã cài đặt và môi trường nền tảng OK
  # Chỉ thất bại nếu có lỗi nghiêm trọng
  if [[ $ios_status -eq 0 && $android_status -eq 0 && $doctor_status -ne 1 ]]; then
    echo -e "${GREEN}=== KIỂM TRA FLUTTER THÀNH CÔNG ===${NC}"
    exit 0
  elif [[ $version_status -eq 2 || $doctor_status -eq 2 || $plugin_status -eq 2 ]]; then
    echo -e "${YELLOW}=== KIỂM TRA FLUTTER HOÀN TẤT VỚI CẢNH BÁO ===${NC}"
    exit 2
  else
    echo -e "${RED}=== KIỂM TRA FLUTTER THẤT BẠI ===${NC}"
    exit 1
  fi
}

# Chạy hàm chính
main "$@" 