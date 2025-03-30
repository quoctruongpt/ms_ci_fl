#!/bin/bash

# Script xuất Unity module cho Flutter
# ==================================

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Đường dẫn
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UNITY_PROJECT_DIR="${ROOT_DIR}/src/unity_project"
FLUTTER_PROJECT_DIR="${ROOT_DIR}/src/flutter_project"
LOG_DIR="${ROOT_DIR}/logs/unity"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"

# Đảm bảo thư mục log và artifacts tồn tại
mkdir -p "$LOG_DIR"
mkdir -p "$ARTIFACTS_DIR"

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

# Sửa build.gradle để thay đổi ndkDirectory thành ndkPath
fix_build_gradle() {
  local platform="$1"
  
  if [[ "$platform" == "android" ]]; then
    local build_gradle="${FLUTTER_PROJECT_DIR}/android/unityLibrary/build.gradle"
    
    if [[ -f "$build_gradle" ]]; then
      echo -e "${YELLOW}Sửa đổi file build.gradle...${NC}"
      
      # Tạo bản sao lưu trước khi sửa
      cp "$build_gradle" "${build_gradle}.bak"
      
      # Thay thế ndkDirectory bằng ndkPath
      sed -i.tmp 's/commandLineArgs.add("--tool-chain-path=" + android.ndkDirectory)/commandLineArgs.add("--tool-chain-path=" + android.ndkPath)/g' "$build_gradle"
      
      # Xóa file tạm (chỉ macOS)
      if [[ -f "${build_gradle}.tmp" ]]; then
        rm "${build_gradle}.tmp"
      fi
      
      echo -e "${GREEN}[OK] Đã sửa build.gradle để sử dụng android.ndkPath thay vì android.ndkDirectory${NC}"
    else
      echo -e "${RED}[LỖI] Không tìm thấy file build.gradle tại: $build_gradle${NC}"
      return 1
    fi
  fi
  
  return 0
}

# Xuất Unity module
export_unity_module() {
  local platform="$1"
  local unity_version="$2"
  local unity_executable=$(get_unity_path "$unity_version")
  local log_file="$LOG_DIR/export_module_${platform}.log"
  
  # Thiết lập đường dẫn xuất cho platform
  local export_path=""
  if [[ "$platform" == "android" ]]; then
    export_path="${ARTIFACTS_DIR}/unity_android_module"
  elif [[ "$platform" == "ios" ]]; then
    export_path="${ARTIFACTS_DIR}/unity_ios_module"
  else
    echo -e "${RED}[LỖI] Platform không hợp lệ: $platform${NC}"
    return 1
  fi
  
  # Đảm bảo thư mục xuất trống
  rm -rf "$export_path"
  mkdir -p "$export_path"

  # Kiểm tra Unity executable
  if [[ ! -f "$unity_executable" ]]; then
    echo -e "${RED}[LỖI] Không tìm thấy Unity executable tại: $unity_executable${NC}"
    return 1
  fi

  echo -e "${YELLOW}Xuất Unity module cho $platform...${NC}"

  # Thực hiện xuất module
  "$unity_executable" \
    -batchmode \
    -nographics \
    -silent-crashes \
    -logFile "$log_file" \
    -projectPath "$UNITY_PROJECT_DIR" \
    -executeMethod "ExportModuleAutomation.ExportForPlatform" \
    -exportPath "$export_path" \
    -platform "$platform" \
    -quit

  # Kiểm tra trạng thái thoát
  local exit_status=$?
  if [[ $exit_status -ne 0 ]]; then
    echo -e "${RED}[LỖI] Xuất Unity module thất bại với mã lỗi: $exit_status${NC}"
    echo -e "${RED}Xem log tại: $log_file${NC}"
    return 1
  fi

  # Di chuyển module vào thư mục Flutter
  if [[ "$platform" == "android" ]]; then
    local target_dir="${FLUTTER_PROJECT_DIR}/android/unityLibrary"
    rm -rf "$target_dir"
    mkdir -p "${FLUTTER_PROJECT_DIR}/android"
    cp -R "$export_path" "$target_dir"
    echo -e "${GREEN}[OK] Đã sao chép Unity module vào ${target_dir}${NC}"
    
    # Sửa build.gradle
    fix_build_gradle "android"
  elif [[ "$platform" == "ios" ]]; then
    local target_dir="${FLUTTER_PROJECT_DIR}/ios/UnityLibrary"
    rm -rf "$target_dir"
    mkdir -p "${FLUTTER_PROJECT_DIR}/ios"
    cp -R "$export_path" "$target_dir"
    echo -e "${GREEN}[OK] Đã sao chép Unity module vào ${target_dir}${NC}"
  fi

  echo -e "${GREEN}[OK] Đã xuất Unity module cho $platform${NC}"
  echo -e "${GREEN}Log tại: $log_file${NC}"
  return 0
}

# Hàm chính
main() {
  local platform=$1
  local unity_version=${2:-"2022.3.57f1"}

  echo "=== XUẤT UNITY MODULE CHO FLUTTER ==="
  echo "Platform đích: $platform"
  echo "Phiên bản Unity: $unity_version"

  # Kiểm tra platform
  if [[ ! "$platform" =~ ^(android|ios)$ ]]; then
    echo -e "${RED}[LỖI] Platform không hợp lệ: $platform. Hãy sử dụng android hoặc ios.${NC}"
    exit 1
  fi

  # Kiểm tra iOS trên OS không phải macOS
  if [[ "$platform" == "ios" && "$(detect_os)" != "macos" ]]; then
    echo -e "${RED}[LỖI] Không thể xuất Unity module cho iOS trên hệ điều hành không phải macOS.${NC}"
    exit 1
  fi

  # Kiểm tra Unity project
  check_unity_project
  if [[ $? -ne 0 ]]; then
    exit 1
  fi

  # Xuất Unity module
  export_unity_module "$platform" "$unity_version"
  exit $?
}

# Kiểm tra số lượng tham số
if [[ $# -lt 1 ]]; then
  echo "Sử dụng: $0 <platform> [unity_version]"
  echo "  <platform>      Platform đích (android hoặc ios)"
  echo "  [unity_version] Phiên bản Unity (mặc định: 2022.3.57f1)"
  exit 1
fi

main "$@"
