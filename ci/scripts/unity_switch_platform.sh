#!/bin/bash

# Script chuyển đổi platform Unity
# ================================

# Màu sắc cho output
RED='🔴'
GREEN='🟢'
YELLOW='🟡'
NC='' # N

# Đường dẫn
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UNITY_PROJECT_DIR="${ROOT_DIR}/src/unity_project"
LOG_DIR="${ROOT_DIR}/logs/unity"

# Đảm bảo thư mục log tồn tại
mkdir -p "$LOG_DIR"

# Phát hiện hệ điều hành
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "linux"
  else
    echo "unsupported"
  fi
}

# Lấy đường dẫn Unity dựa trên hệ điều hành
get_unity_path() {
  local unity_version="$1"
  local detected_os=$(detect_os)

  if [[ "$detected_os" == "macos" ]]; then
    echo "/Applications/Unity/Hub/Editor/$unity_version/Unity.app/Contents/MacOS/Unity"
  elif [[ "$detected_os" == "linux" ]]; then
    echo "/opt/unity/Editor/$unity_version/Editor/Unity"
  else
    echo ""
  fi
}

# Kiểm tra Unity project
check_unity_project() {
  if [[ ! -d "$UNITY_PROJECT_DIR" ]]; then
    echo -e "${RED}[LỖI] Không tìm thấy thư mục Unity project tại: $UNITY_PROJECT_DIR${NC}"
    return 1
  fi

  if [[ ! -d "$UNITY_PROJECT_DIR/Assets" ]]; then
    echo -e "${RED}[LỖI] Không tìm thấy thư mục Assets trong Unity project${NC}"
    return 1
  fi

  if [[ ! -d "$UNITY_PROJECT_DIR/ProjectSettings" ]]; then
    echo -e "${RED}[LỖI] Không tìm thấy thư mục ProjectSettings trong Unity project${NC}"
    return 1
  fi

  return 0
}

# Chuyển đổi platform (sử dụng tham số -buildTarget)
switch_platform() {
  local platform="$1"
  local unity_version="$2"
  local unity_executable=$(get_unity_path "$unity_version")
  local log_file="$LOG_DIR/switch_platform_${platform}.log"
  local build_target=""
  
  # Chuyển đổi platform thành buildTarget của Unity
  if [[ "$platform" == "android" ]]; then
    build_target="Android"
  elif [[ "$platform" == "ios" ]]; then
    build_target="iOS"
  else
    echo -e "${RED}[LỖI] Platform không hợp lệ: $platform${NC}"
    return 1
  fi

  # Kiểm tra Unity executable
  if [[ ! -f "$unity_executable" ]]; then
    echo -e "${RED}[LỖI] Không tìm thấy Unity executable tại: $unity_executable${NC}"
    return 1
  fi

  echo -e "${YELLOW}Chuyển đổi Unity platform sang $platform...${NC}"

  # Thực hiện chuyển đổi platform
  "$unity_executable" \
    -batchmode \
    -nographics \
    -silent-crashes \
    -logFile "$log_file" \
    -projectPath "$UNITY_PROJECT_DIR" \
    -buildTarget "$build_target" \
    -quit

  # Kiểm tra trạng thái thoát
  local exit_status=$?
  if [[ $exit_status -ne 0 ]]; then
    echo -e "${RED}[LỖI] Chuyển đổi platform thất bại với mã lỗi: $exit_status${NC}"
    echo -e "${RED}Xem log tại: $log_file${NC}"
    return 1
  fi

  echo -e "${GREEN}[OK] Đã chuyển đổi Unity platform sang $platform${NC}"
  echo -e "${GREEN}Log tại: $log_file${NC}"
  return 0
}

# Hàm chính
main() {
  local platform=$1
  local unity_version=${2:-"2022.3.57f1"}

  echo "=== CHUYỂN ĐỔI PLATFORM UNITY ==="
  echo "Nền tảng đích: $platform"
  echo "Phiên bản Unity: $unity_version"

  # Kiểm tra platform
  if [[ ! "$platform" =~ ^(android|ios)$ ]]; then
    echo -e "${RED}[LỖI] Platform không hợp lệ: $platform. Hãy sử dụng android hoặc ios.${NC}"
    exit 1
  fi

  # Kiểm tra Unity project
  check_unity_project
  if [[ $? -ne 0 ]]; then
    exit 1
  fi

  # Chuyển đổi platform
  switch_platform "$platform" "$unity_version"
  exit $?
}

# Chạy script
if [[ $# -lt 1 ]]; then
  echo "Sử dụng: $0 <platform> [unity_version]"
  echo "  <platform>      Platform đích (android hoặc ios)"
  echo "  [unity_version] Phiên bản Unity (mặc định: 2022.3.57f1)"
  exit 1
fi

main "$@" 