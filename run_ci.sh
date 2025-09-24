#!/bin/bash

# Script chính để chạy CI/CD
# ============================

# Xác định đường dẫn gốc
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Màu sắc cho output
RED='🔴'
GREEN='🟢'
YELLOW='🟡'
NC='' # No Color

echo "xin chào"

# Source cấu hình Telegram
# if [ -f "$ROOT_DIR/ci/config/telegram_config.sh" ]; then
#     source "$ROOT_DIR/ci/config/telegram_config.sh"
    
#     # Kiểm tra cấu hình Telegram
#     if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
#         echo -e "${RED}[LỖI] Thiếu cấu hình Telegram. Vui lòng kiểm tra file ci/config/telegram_config.sh${NC}"
#         exit 1
#     fi
# else
#     echo -e "${RED}[LỖI] Không tìm thấy file cấu hình Telegram: ci/config/telegram_config.sh${NC}"
#     exit 1
# fi

# Source script thông báo Telegram
if [ -f "$ROOT_DIR/ci/scripts/telegram/notify.sh" ]; then
    source "$ROOT_DIR/ci/scripts/telegram/notify.sh"
else
    echo -e "${RED}[LỖI] Không tìm thấy file script thông báo Telegram: ci/scripts/telegram/notify.sh${NC}"
    exit 1
fi

# Mặc định là xây dựng cho Android và nhánh main cho cả Flutter và Unity
PLATFORM="android"
UNITY_VERSION="2022.3.57f1"
FLUTTER_BRANCH="main"
UNITY_BRANCH="main"
BUILD_TYPE="test"  # Mặc định là build test

# Xử lý tham số
show_help() {
  echo "Sử dụng: $0 [options]"
  echo "Options:"
  echo "  -p, --platform <platform>     Chọn nền tảng để build (android hoặc ios). Mặc định: android"
  echo "  -u, --unity <version>         Chỉ định phiên bản Unity. Mặc định: 2022.3.57f1"
  echo "  -f, --flutter-branch <branch> Chỉ định git branch cho dự án Flutter. Mặc định: main"
  echo "  -t, --unity-branch <branch>   Chỉ định git branch cho dự án Unity. Mặc định: main"
  echo "  -b, --build-type <type>       Chỉ định loại build (test hoặc release). Mặc định: test"
  echo "                                - test: Chỉ build debug APK cho Android"
  echo "                                - release: Build release APK và AAB cho Android"
  echo "  -h, --help                    Hiển thị trợ giúp này"
}

# Xử lý các tham số dòng lệnh
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -p|--platform)
      PLATFORM="$2"
      shift 2
      ;;
    -u|--unity)
      UNITY_VERSION="$2"
      shift 2
      ;;
    -f|--flutter-branch)
      FLUTTER_BRANCH="$2"
      shift 2
      ;;
    -t|--unity-branch)
      UNITY_BRANCH="$2"
      shift 2
      ;;
    -b|--build-type)
      BUILD_TYPE="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}[LỖI] Tham số không xác định: $1${NC}"
      show_help
      exit 1
      ;;
  esac
done

# Kiểm tra giá trị platform hợp lệ
if [[ ! "$PLATFORM" =~ ^(android|ios)$ ]]; then
  echo -e "${RED}[LỖI] Giá trị platform không hợp lệ: $PLATFORM. Hãy sử dụng android hoặc ios.${NC}"
  exit 1
fi

# Kiểm tra giá trị build_type hợp lệ
if [[ ! "$BUILD_TYPE" =~ ^(test|release)$ ]]; then
  echo -e "${RED}[LỖI] Giá trị build_type không hợp lệ: $BUILD_TYPE. Hãy sử dụng test hoặc release.${NC}"
  exit 1
fi

# Gửi thông báo bắt đầu build
send_telegram_start "$PLATFORM" "$BUILD_TYPE" "$FLUTTER_BRANCH" "$UNITY_BRANCH"

echo -e "${YELLOW}Bắt đầu quá trình CI cho platform: $PLATFORM${NC}"
echo -e "${YELLOW}Flutter branch: $FLUTTER_BRANCH${NC}"
echo -e "${YELLOW}Unity branch: $UNITY_BRANCH${NC}"
echo -e "${YELLOW}Loại build: $BUILD_TYPE${NC}"

# Chuyển đổi git branch thông qua script riêng
echo -e "${YELLOW}Chuyển đổi git branch...${NC}"
export ROOT_DIR
"$ROOT_DIR/ci/scripts/git/checkout_branch.sh" "$FLUTTER_BRANCH" "$UNITY_BRANCH"
if [[ $? -ne 0 ]]; then
  echo -e "${RED}[LỖI] Không thể chuyển đổi git branch. Hãy kiểm tra log để biết chi tiết.${NC}"
  # Lấy commit ở đây không còn ý nghĩa vì checkout đã thất bại, gửi thông báo lỗi ngay
  send_telegram_error "$PLATFORM" "$BUILD_TYPE" "$FLUTTER_BRANCH" "N/A" "$UNITY_BRANCH" "N/A" "Git Checkout Failed" "Không thể chuyển đổi git branch"
  exit 1
fi

# Lấy commit hash và message của Flutter và Unity SAU KHI checkout thành công
echo -e "${YELLOW}Lấy thông tin commit sau khi checkout...${NC}"
FLUTTER_COMMIT=$(cd "$ROOT_DIR/src/flutter_project" && git rev-parse --short HEAD)
FLUTTER_COMMIT_MSG=$(cd "$ROOT_DIR/src/flutter_project" && git log -1 --pretty=%B)
UNITY_COMMIT=$(cd "$ROOT_DIR/src/unity_project" && git rev-parse --short HEAD)
UNITY_COMMIT_MSG=$(cd "$ROOT_DIR/src/unity_project" && git log -1 --pretty=%B)

# Gửi thông báo sau khi checkout thành công
CHECKOUT_MSG="✅ *Checkout thành công!*
    𝑭 Flutter: ${FLUTTER_BRANCH} - ${FLUTTER_COMMIT}
    ⤷ ${FLUTTER_COMMIT_MSG}
    𝓤 Unity: ${UNITY_BRANCH} - ${UNITY_COMMIT}
    ⤷ ${UNITY_COMMIT_MSG}"
send_google_chat_message "$CHECKOUT_MSG"

# Kiểm tra môi trường Unity
echo -e "${YELLOW}Kiểm tra môi trường Unity...${NC}"
"$ROOT_DIR/tools/unity_license_activation/check_unity.sh"

# Kiểm tra kết quả của script kiểm tra Unity
if [[ $? -eq 0 ]]; then
  echo -e "${GREEN}Môi trường Unity OK. Tiếp tục quy trình...${NC}"
else
  echo -e "${RED}Kiểm tra môi trường Unity thất bại. Hãy cài đặt Unity phiên bản $UNITY_VERSION trước khi tiếp tục.${NC}"
  send_telegram_error "$PLATFORM" "$BUILD_TYPE" "$FLUTTER_BRANCH" "$FLUTTER_COMMIT" "$UNITY_BRANCH" "$UNITY_COMMIT" "Unity Environment Check Failed" "Kiểm tra môi trường Unity thất bại. Hãy cài đặt Unity phiên bản $UNITY_VERSION"
  exit 1
fi

# Kiểm tra môi trường Flutter
echo -e "${YELLOW}Kiểm tra môi trường Flutter...${NC}"
"$ROOT_DIR/tools/dependency_checker/check_flutter.sh" "$ROOT_DIR/src/flutter_project"

# Kiểm tra kết quả của script kiểm tra Flutter
flutter_check_status=$?
if [[ $flutter_check_status -eq 0 ]]; then
  echo -e "${GREEN}Môi trường Flutter OK. Tiếp tục quy trình...${NC}"
elif [[ $flutter_check_status -eq 2 ]]; then
  echo -e "${YELLOW}Môi trường Flutter có cảnh báo nhưng có thể tiếp tục quy trình. Kiểm tra log để biết chi tiết.${NC}"
else
  echo -e "${RED}Kiểm tra môi trường Flutter thất bại. Kiểm tra log để biết chi tiết.${NC}"
  send_telegram_error "$PLATFORM" "$BUILD_TYPE" "$FLUTTER_BRANCH" "$FLUTTER_COMMIT" "$UNITY_BRANCH" "$UNITY_COMMIT" "Flutter Environment Check Failed" "Kiểm tra môi trường Flutter thất bại"
  exit 1
fi

# Kiểm tra các yêu cầu cụ thể cho nền tảng đã chọn
case $PLATFORM in
  android)
    echo -e "${YELLOW}Kiểm tra môi trường Android...${NC}"
    # Kiểm tra thêm các yêu cầu cụ thể cho Android nếu cần
    ;;
  ios)
    echo -e "${YELLOW}Kiểm tra môi trường iOS...${NC}"
    # Kiểm tra macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
      echo -e "${RED}[LỖI] Không thể build cho iOS trên hệ điều hành không phải macOS.${NC}"
      send_telegram_error "$PLATFORM" "$BUILD_TYPE" "$FLUTTER_BRANCH" "$FLUTTER_COMMIT" "$UNITY_BRANCH" "$UNITY_COMMIT" "iOS Build Environment Error" "Không thể build cho iOS trên hệ điều hành không phải macOS"
      exit 1
    fi
    ;;
esac

# Hiển thị thông tin build
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   CI Build cho platform: $PLATFORM${NC}"
echo -e "${GREEN}   Flutter branch: $FLUTTER_BRANCH${NC}"
echo -e "${GREEN}   Unity branch: $UNITY_BRANCH${NC}"
echo -e "${GREEN}   Loại build: $BUILD_TYPE${NC}"
echo -e "${GREEN}=========================================${NC}"

# Chuyển đổi platform Unity sang platform tương ứng
echo -e "${YELLOW}Chuyển đổi Unity platform sang $PLATFORM...${NC}"
"$ROOT_DIR/ci/scripts/unity_switch_platform.sh" "$PLATFORM" "$UNITY_VERSION"

# Kiểm tra kết quả của script chuyển đổi platform
if [[ $? -eq 0 ]]; then
  echo -e "${GREEN}Chuyển đổi Unity platform thành công.${NC}"
else
  echo -e "${RED}Chuyển đổi Unity platform thất bại.${NC}"
  send_telegram_error "$PLATFORM" "$BUILD_TYPE" "$FLUTTER_BRANCH" "$FLUTTER_COMMIT" "$UNITY_BRANCH" "$UNITY_COMMIT" "Unity Platform Switch Failed" "Chuyển đổi Unity platform thất bại"
  exit 1
fi

# Xuất Unity module cho Flutter
echo -e "${YELLOW}Xuất Unity module cho Flutter platform $PLATFORM...${NC}"
"$ROOT_DIR/ci/scripts/unity_export_module.sh" "$PLATFORM" "$UNITY_VERSION"

# Kiểm tra kết quả của việc xuất Unity module
if [[ $? -eq 0 ]]; then
  echo -e "${GREEN}Xuất Unity module thành công.${NC}"
  send_telegram_unity_export "success" "$PLATFORM" "$BUILD_TYPE" "$UNITY_BRANCH" "$UNITY_COMMIT"
else
  echo -e "${RED}Xuất Unity module thất bại.${NC}"
  send_telegram_unity_export "error" "$PLATFORM" "$BUILD_TYPE" "$UNITY_BRANCH" "$UNITY_COMMIT"
  send_telegram_error "$PLATFORM" "$BUILD_TYPE" "$FLUTTER_BRANCH" "$FLUTTER_COMMIT" "$UNITY_BRANCH" "$UNITY_COMMIT" "Unity Export Failed" "Xuất Unity module thất bại"
  exit 1
fi

# Thực hiện build dự án Flutter cho từng nền tảng
echo -e "${YELLOW}Tiến hành build Flutter cho $PLATFORM...${NC}"

# Kiểm tra và sao chép file .env
echo -e "${YELLOW}Kiểm tra file môi trường...${NC}"
if [ ! -f "$ROOT_DIR/src/flutter_project/.env.dev" ] || [ ! -f "$ROOT_DIR/src/flutter_project/.env.prod" ]; then
    echo -e "${YELLOW}Sao chép file .env từ thư mục env...${NC}"
    
    # Sao chép .env.dev với log lỗi chi tiết
    if ! cp "$ROOT_DIR/env/.env.dev" "$ROOT_DIR/src/flutter_project/.env.dev" 2> /tmp/cp_error.log; then
        error_msg=$(cat /tmp/cp_error.log)
        echo -e "${RED}[LỖI] Không thể sao chép file .env.dev${NC}"
        echo -e "${RED}Chi tiết lỗi: $error_msg${NC}"
        send_telegram_error "$PLATFORM" "$BUILD_TYPE" "$FLUTTER_BRANCH" "$FLUTTER_COMMIT" "$UNITY_BRANCH" "$UNITY_COMMIT" "Environment Setup Failed" "Không thể sao chép file .env.dev: $error_msg"
        rm -f /tmp/cp_error.log
        exit 1
    fi
    
    # Sao chép .env.prod với log lỗi chi tiết
    if ! cp "$ROOT_DIR/env/.env.prod" "$ROOT_DIR/src/flutter_project/.env.prod" 2> /tmp/cp_error.log; then
        error_msg=$(cat /tmp/cp_error.log)
        echo -e "${RED}[LỖI] Không thể sao chép file .env.prod${NC}"
        echo -e "${RED}Chi tiết lỗi: $error_msg${NC}"
        send_telegram_error "$PLATFORM" "$BUILD_TYPE" "$FLUTTER_BRANCH" "$FLUTTER_COMMIT" "$UNITY_BRANCH" "$UNITY_COMMIT" "Environment Setup Failed" "Không thể sao chép file .env.prod: $error_msg"
        rm -f /tmp/cp_error.log
        exit 1
    fi
    
    rm -f /tmp/cp_error.log
    echo -e "${GREEN}Đã sao chép file .env thành công${NC}"
else
    echo -e "${GREEN}Các file .env đã tồn tại${NC}"
fi

case $PLATFORM in
  android)
    # Build cho Android
    echo -e "${YELLOW}Build ứng dụng Android...${NC}"
    BUILD_URLS=$("$ROOT_DIR/ci/scripts/flutter/build_android.sh" "$BUILD_TYPE")
    if [[ $? -eq 0 ]]; then
      APK_URL=$(echo "$BUILD_URLS" | grep -o 'https://[^ ]*')
        
        # Lấy thông tin version từ app/build.gradle
        echo -e "${YELLOW}Lấy thông tin version từ app/build.gradle...${NC}"
        
        # Đọc versionName từ app/build.gradle
        VERSION_NAME=$(grep -o 'versionName\s*=\s*"[0-9.]*"' "$ROOT_DIR/src/flutter_project/android/app/build.gradle.kts" | sed 's/.*"\\(.*\\)".*/\\1/')
                
        # Đọc versionCode từ app/build.gradle
        VERSION_CODE=$(grep -o "versionCode\s*=\s*[0-9]*" "$ROOT_DIR/src/flutter_project/android/app/build.gradle.kts" | grep -o "[0-9]*")
        
        # Gửi thông báo hoàn thành
        send_telegram_finish "$PLATFORM" "$BUILD_TYPE" "$FLUTTER_BRANCH" "$FLUTTER_COMMIT" "$FLUTTER_COMMIT_MSG" "$UNITY_BRANCH" "$UNITY_COMMIT" "$UNITY_COMMIT_MSG" "$VERSION_CODE" "$VERSION_NAME" "$APK_URL"
    else
      echo -e "${RED}[LỖI] Build Android thất bại.${NC}"
      send_telegram_error "$PLATFORM" "$BUILD_TYPE" "$FLUTTER_BRANCH" "$FLUTTER_COMMIT" "$UNITY_BRANCH" "$UNITY_COMMIT" "Android Build Failed" "Build Android thất bại"
      exit 1
    fi
    ;;
  ios)
    # Build cho iOS và chạy fastlane
    echo -e "${YELLOW}Build ứng dụng iOS và chạy fastlane...${NC}"
    
    # Clean và get dependencies cho dự án Flutter
    echo -e "${YELLOW}Clean và get dependencies cho dự án Flutter...${NC}"
    cd "$ROOT_DIR/src/flutter_project" 
    flutter clean
    flutter pub get
    if [[ $? -ne 0 ]]; then
      echo -e "${RED}[LỖI] flutter clean hoặc flutter pub get thất bại.${NC}"
      send_telegram_error "$PLATFORM" "$BUILD_TYPE" "$FLUTTER_BRANCH" "$FLUTTER_COMMIT" "$UNITY_BRANCH" "$UNITY_COMMIT" "Flutter Clean/Get Failed (iOS)" "flutter clean hoặc flutter pub get thất bại cho iOS"
      exit 1
    fi
    
    # Precache Flutter engine cho iOS
    echo -e "${YELLOW}Đang precache Flutter engine cho iOS...${NC}"
    flutter precache --ios
    if [[ $? -ne 0 ]]; then
      echo -e "${RED}[LỖI] flutter precache --ios thất bại.${NC}"
      send_telegram_error "$PLATFORM" "$BUILD_TYPE" "$FLUTTER_BRANCH" "$FLUTTER_COMMIT" "$UNITY_BRANCH" "$UNITY_COMMIT" "Flutter Precache Failed (iOS)" "flutter precache --ios thất bại"
      exit 1
    fi
    
    cd "$ROOT_DIR/src/flutter_project/ios"
    if [[ $? -ne 0 ]]; then
      echo -e "${RED}[LỖI] Không thể chuyển đến thư mục flutter_project/ios.${NC}"
      send_telegram_error "$PLATFORM" "$BUILD_TYPE" "$FLUTTER_BRANCH" "$FLUTTER_COMMIT" "$UNITY_BRANCH" "$UNITY_COMMIT" "iOS Directory Error" "Không thể chuyển đến thư mục flutter_project/ios"
      exit 1
    fi
    
    echo -e "${YELLOW}Đang dọn dẹp pod...${NC}"
    pod cache clean --all
    rm -rf Pods/
    rm -f Podfile.lock
    
    echo -e "${YELLOW}Chạy pod install...${NC}"
    pod install
    
    # Tạo thư mục logs nếu chưa tồn tại
    mkdir -p "$ROOT_DIR/logs"
    
    # Tạo tên file log với timestamp
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    FASTLANE_LOG="$ROOT_DIR/logs/fastlane_${TIMESTAMP}.log"
    
    # Chạy fastlane beta và lưu log
    echo -e "${YELLOW}Chạy fastlane beta...${NC}"
    echo -e "${YELLOW}Log sẽ được lưu tại: $FASTLANE_LOG${NC}"
    
    # Kiểm tra đã cài đặt fastlane chưa và phiên bản có phải là 2.227.0 không
    echo -e "${YELLOW}Kiểm tra phiên bản fastlane...${NC}"
   
      fastlane_version=$(fastlane --version | head -n1 | grep -o '[0-9.]*')
      echo -e "${GREEN}Đã phát hiện fastlane phiên bản $fastlane_version.${NC}"
      
      # Nếu phiên bản không đúng, chỉ cảnh báo nhưng không bắt buộc cập nhật
      if [[ "$fastlane_version" != "2.227.0" ]]; then
        echo -e "${YELLOW}Cảnh báo: Phiên bản fastlane được khuyến nghị là 2.227.0, nhưng đang dùng $fastlane_version.${NC}"
        echo -e "${YELLOW}Tiếp tục chạy với phiên bản hiện tại. Nếu gặp vấn đề, hãy cập nhật thủ công.${NC}"
      else
        echo -e "${GREEN}Fastlane 2.227.0 đã được cài đặt.${NC}"
      fi
    
    
    fastlane beta 2>&1 | tee -a "$FASTLANE_LOG"
    fastlane_status=${PIPESTATUS[0]}

    if [[ $fastlane_status -eq 0 ]]; then
      echo "✅ Build thành công"
    else
      echo "❌ Build thất bại"
      exit 1
    fi

     # Lấy thông tin version trước khi build
    echo -e "${YELLOW}Lấy thông tin version...${NC}"
    version_info=$(fastlane get_version)
     # Cách đúng để lấy version từ output của fastlane
    if echo "$version_info" | grep -q "\[.*\]: Version Code:"; then
      version_code=$(echo "$version_info" | grep "\[.*\]: Version Code:" | head -1 | sed 's/.*Version Code: //')
      version_name=$(echo "$version_info" | grep "\[.*\]: Version Name:" | head -1 | sed 's/.*Version Name: //')
    else
      # Fallback nếu không tìm thấy theo định dạng trên
      version_code=$(echo "$version_info" | grep "Version Code:" | head -1 | cut -d':' -f2 | tr -d ' ')
      version_name=$(echo "$version_info" | grep "Version Name:" | head -1 | cut -d':' -f2 | tr -d ' ')
    fi
    
    # Kiểm tra kết quả của fastlane
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
      echo -e "${GREEN}Build iOS và upload lên TestFlight thành công.${NC}"
      
      # Gửi thông báo hoàn thành với version từ Fastlane
      send_telegram_finish \
        "$PLATFORM" \
        "$BUILD_TYPE" \
        "$FLUTTER_BRANCH" \
        "$FLUTTER_COMMIT" \
        "$FLUTTER_COMMIT_MSG" \
        "$UNITY_BRANCH" \
        "$UNITY_COMMIT" \
        "$UNITY_COMMIT_MSG" \
        "$version_code" \
        "$version_name"
    else
      echo -e "${RED}[LỖI] Build iOS hoặc upload lên TestFlight thất bại.${NC}"
      echo -e "${RED}Kiểm tra log tại: $FASTLANE_LOG${NC}"
      send_telegram_error "$PLATFORM" "$BUILD_TYPE" "$FLUTTER_BRANCH" "$FLUTTER_COMMIT" "$UNITY_BRANCH" "$UNITY_COMMIT" "iOS Build Failed" "Build iOS hoặc upload lên TestFlight thất bại"
      exit 1
    fi
    ;;
esac

echo -e "${GREEN}Quá trình CI hoàn tất thành công!${NC}"
echo -e "${GREEN}Sản phẩm build được lưu trong thư mục: ${ROOT_DIR}/artifacts/${PLATFORM}${NC}" 