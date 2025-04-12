#!/bin/bash

# Script kiểm tra Unity version 2022.3.57f1
# ===========================================

# Xác định màu cho output
RED='🔴'
GREEN='🟢'
YELLOW='🟡'
NC='' # N

# Kiểm tra hệ điều hành
check_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "linux"
  else
    echo "unsupported"
  fi
}

# Đường dẫn tới Unity dựa vào hệ điều hành
get_unity_path() {
  local unity_version="$1"
  local os=$(check_os)

  if [[ "$os" == "macos" ]]; then
    echo "/Applications/Unity/Hub/Editor/$unity_version/Unity.app/Contents/MacOS/Unity"
  elif [[ "$os" == "linux" ]]; then
    echo "/opt/unity/Editor/$unity_version/Editor/Unity"
  else
    echo ""
  fi
}

# Kiểm tra Unity version
check_unity_version() {
  local required_version="$1"
  local unity_path=$(get_unity_path "$required_version")

  echo -e "${YELLOW}Kiểm tra Unity phiên bản $required_version...${NC}"
  
  # Kiểm tra xem đường dẫn tới Unity có tồn tại không
  if [[ ! -f "$unity_path" ]]; then
    echo -e "${RED}[LỖI] Unity $required_version không được cài đặt tại $unity_path${NC}"
    return 1
  fi
  
  # Kiểm tra phiên bản Unity
  if [[ "$os" == "macos" ]]; then
    local version_info=$("$unity_path" -version 2>&1 | head -n 1)
  else
    local version_info=$("$unity_path" -version 2>&1 | head -n 1)
  fi
  
  echo "Thông tin phiên bản: $version_info"
  
  # Kiểm tra xem version_info có chứa required_version không
  if [[ "$version_info" == *"$required_version"* ]]; then
    echo -e "${GREEN}[OK] Unity $required_version đã được cài đặt.${NC}"
    return 0
  else
    echo -e "${RED}[LỖI] Phiên bản Unity không khớp. Tìm thấy: $version_info, Yêu cầu: $required_version${NC}"
    return 1
  fi
}

# Kiểm tra license Unity
check_unity_license() {
  local unity_path=$(get_unity_path "$1")
  
  echo -e "${YELLOW}Kiểm tra Unity license...${NC}"
  
  # Chạy Unity với tham số -quit để kiểm tra license
  "$unity_path" -batchmode -quit -logFile - 2>&1 | grep -i "license"
  
  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}[OK] Unity license hợp lệ.${NC}"
    return 0
  else
    echo -e "${RED}[CẢNH BÁO] Có thể có vấn đề với Unity license.${NC}"
    return 1
  fi
}

# Hàm chính
main() {
  local required_unity_version="2022.3.57f1"
  local os=$(check_os)
  
  echo "=== KIỂM TRA MÔI TRƯỜNG UNITY ==="
  echo "Hệ điều hành: $os"
  
  if [[ "$os" == "unsupported" ]]; then
    echo -e "${RED}[LỖI] Hệ điều hành không được hỗ trợ.${NC}"
    exit 1
  fi
  
  # Kiểm tra phiên bản Unity
  check_unity_version "$required_unity_version"
  local version_status=$?
  
  # Kiểm tra Unity license (nếu Unity đã được cài đặt)
  if [[ $version_status -eq 0 ]]; then
    check_unity_license "$required_unity_version"
    local license_status=$?
    
    if [[ $license_status -eq 0 ]]; then
      echo -e "${GREEN}=== KIỂM TRA UNITY THÀNH CÔNG ===${NC}"
      exit 0
    else
      echo -e "${YELLOW}=== KIỂM TRA UNITY HOÀN TẤT VỚI CẢNH BÁO ===${NC}"
      exit 2
    fi
  else
    echo -e "${RED}=== KIỂM TRA UNITY THẤT BẠI ===${NC}"
    exit 1
  fi
}

# Chạy hàm chính
main 