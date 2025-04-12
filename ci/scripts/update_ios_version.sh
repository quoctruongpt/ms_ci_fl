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
# Thêm đường dẫn thư mục gốc
ROOT_DIR="$(cd "$(dirname "$0")/../../" && pwd)"
INFO_PLIST_PATH="$IOS_PATH/Runner/Info.plist" # Đường dẫn tiêu chuẩn cho Info.plist trong Flutter
# Thêm đường dẫn thư mục Flutter
FLUTTER_PROJECT_DIR="$ROOT_DIR/src/flutter_project"

# Kiểm tra thư mục iOS có tồn tại không
if [ ! -d "$IOS_PATH" ]; then
  echo "Lỗi: Không tìm thấy thư mục iOS tại $IOS_PATH"
  exit 1
fi

echo "=== Bắt đầu cập nhật version name iOS ==="
echo "Version mới: $NEW_VERSION"
echo "Đường dẫn thư mục iOS: $IOS_PATH"

# --- Checkout main branch in flutter_project ---
echo -e "${YELLOW}Đang chuẩn bị nhánh main trong dự án Flutter ($FLUTTER_PROJECT_DIR)...${NC}"
cd "$FLUTTER_PROJECT_DIR" || { echo -e "${RED}[LỖI] Không thể chuyển vào thư mục $FLUTTER_PROJECT_DIR${NC}"; exit 1; }

# --- Dọn dẹp trạng thái Git cục bộ ---
echo -e "${YELLOW}Đang dọn dẹp trạng thái Git cục bộ (reset --hard và clean -fdx)...${NC}"
if ! git reset --hard HEAD; then
    echo -e "${RED}[LỖI] git reset --hard HEAD thất bại. Kiểm tra trạng thái Git.${NC}"
    exit 1
fi
if ! git clean -fdx; then
    echo -e "${RED}[LỖI] git clean -fdx thất bại. Kiểm tra trạng thái Git.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Đã dọn dẹp trạng thái Git cục bộ.${NC}"
# --- Kết thúc dọn dẹp ---

echo -e "${YELLOW}Đang cập nhật thông tin từ remote (git fetch origin)...${NC}"
if ! git fetch origin; then
    echo -e "${RED}[LỖI] git fetch origin thất bại. Kiểm tra kết nối mạng và cấu hình remote.${NC}"
    exit 1
fi

echo -e "${YELLOW}Đang checkout nhánh main (git checkout main)...${NC}"
if ! git checkout main; then
    echo -e "${RED}[LỖI] git checkout main thất bại. Kiểm tra trạng thái Git và đảm bảo không có thay đổi chưa commit hoặc xung đột.${NC}"
    exit 1
fi

# --- Cập nhật nhánh main cục bộ --- 
echo -e "${YELLOW}Đang cập nhật nhánh main cục bộ (git pull origin main)...${NC}"
if ! git pull origin main; then
   echo -e "${RED}[LỖI] git pull origin main thất bại. Kiểm tra xung đột hoặc vấn đề mạng.${NC}"
   exit 1
fi
echo -e "${GREEN}[OK] Đã cập nhật nhánh main cục bộ.${NC}"
# --- Kết thúc cập nhật --- 

echo -e "${GREEN}[OK] Đã chuẩn bị thành công nhánh main.${NC}"
# --- End Checkout/Prepare ---

# Di chuyển đến thư mục iOS để chạy Fastlane
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

# Kiểm tra xem lệnh fastlane có thành công không (dựa vào mã thoát)
if [ $? -eq 0 ]; then
    echo "${GREEN}[OK] Đã cập nhật version name iOS thành công bằng fastlane.${NC}"
    
    # Commit và push thay đổi lên Git
    COMMIT_MSG="update: update version ios to $NEW_VERSION"
    echo -e "${YELLOW}Đang commit thay đổi lên Git với nội dung: '$COMMIT_MSG'${NC}"

    # Chuyển về thư mục dự án Flutter để chạy Git
    cd "$FLUTTER_PROJECT_DIR" || { echo -e "${RED}[LỖI] Không thể quay lại thư mục $FLUTTER_PROJECT_DIR${NC}"; exit 1; }
    
    # Sử dụng đường dẫn tương đối từ FLUTTER_PROJECT_DIR
    git add ios/Runner/Info.plist
    # git add ios/Runner.xcodeproj/project.pbxproj # Bỏ comment nếu cần add cả file project

    # Commit
    if git commit -m "$COMMIT_MSG"; then
        echo -e "${GREEN}[OK] Đã commit thay đổi thành công!${NC}"
        
        # Push
        echo -e "${YELLOW}Đang đẩy commit lên kho lưu trữ từ xa...${NC}"
        if git push; then
             echo -e "${GREEN}[OK] Đã đẩy commit lên kho lưu trữ từ xa thành công!${NC}"
        else
             echo -e "${RED}[LỖI] Không thể đẩy commit lên kho lưu trữ từ xa. Vui lòng kiểm tra cấu hình Git remote và quyền truy cập.${NC}"
             # exit 1 # Tùy chọn: thoát nếu push lỗi
        fi
    else
        echo -e "${RED}[LỖI] Không thể commit thay đổi. Có thể không có thay đổi nào hoặc đã xảy ra lỗi Git khác.${NC}"
        # exit 1 # Tùy chọn: thoát nếu commit lỗi
    fi
    
    # Quay lại thư mục script ban đầu (tùy chọn)
    # cd "$IOS_PATH" || exit 1
else
    echo "${RED}[LỖI] Lệnh fastlane update_version_name thất bại.${NC}"
    exit 1 # Thoát nếu fastlane lỗi
fi

echo "=== Cập nhật version name iOS hoàn tất ==="
