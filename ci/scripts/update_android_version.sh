#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Current directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Root directory of the project
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"
# Path to the build.gradle.kts file
BUILD_GRADLE="$ROOT_DIR/src/flutter_project/android/app/build.gradle.kts"
# Path to the Flutter project directory
FLUTTER_PROJECT_DIR="$ROOT_DIR/src/flutter_project"

# Check if the build.gradle.kts file exists
if [ ! -f "$BUILD_GRADLE" ]; then
    echo -e "${RED}[LỖI] Không tìm thấy file build.gradle.kts tại: $BUILD_GRADLE${NC}"
    exit 1
fi

# --- Checkout main branch in flutter_project ---
echo -e "${YELLOW}Đang chuyển sang nhánh main trong dự án Flutter ($FLUTTER_PROJECT_DIR)...${NC}"
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

echo -e "${GREEN}[OK] Đã checkout thành công nhánh main.${NC}"
# Quan trọng: Không cd về lại, các lệnh sed và git sau sẽ chạy từ flutter_project hoặc sử dụng đường dẫn tuyệt đối
# Lưu ý: Lệnh sed bên dưới sử dụng đường dẫn tuyệt đối $BUILD_GRADLE nên không bị ảnh hưởng bởi việc thay đổi thư mục
# --- End Checkout ---

# Function to display help message
show_help() {
    echo "Cách sử dụng: $0 [options]"
    echo ""
    echo "Tùy chọn:"
    echo "  -c, --code VERSION_CODE    Đặt version code mới"
    echo "  -n, --name VERSION_NAME    Đặt version name mới"
    echo "  -h, --help                 Hiển thị trợ giúp này"
    echo ""
    echo "Ví dụ:"
    echo "  $0 -c 2 -n 4.0.1"
}

# Parse command line arguments
VERSION_CODE=""
VERSION_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--code)
            VERSION_CODE="$2"
            shift 2
            ;;
        -n|--name)
            VERSION_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}[LỖI] Tùy chọn không hợp lệ: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Check if at least one option is provided
if [ -z "$VERSION_CODE" ] && [ -z "$VERSION_NAME" ]; then
    echo -e "${RED}[LỖI] Phải chỉ định ít nhất một tùy chọn: version code hoặc version name${NC}"
    show_help
    exit 1
fi

# Hiển thị nội dung của file để debugging
echo -e "${YELLOW}Kiểm tra dòng version trong file build.gradle.kts:${NC}"
grep -n "versionCode\|versionName" "$BUILD_GRADLE"

# Lấy thông tin phiên bản hiện tại
CURRENT_VERSION_CODE=$(grep "versionCode" "$BUILD_GRADLE" | awk -F'=' '{print $2}' | tr -d ' ')
CURRENT_VERSION_NAME=$(grep "versionName" "$BUILD_GRADLE" | awk -F'=' '{print $2}' | tr -d ' ')
echo -e "${YELLOW}Phiên bản hiện tại: Code = $CURRENT_VERSION_CODE, Name = $CURRENT_VERSION_NAME${NC}"

# Update version code if provided
if [ ! -z "$VERSION_CODE" ]; then
    echo -e "${YELLOW}Đang cập nhật version code từ $CURRENT_VERSION_CODE thành $VERSION_CODE...${NC}"
    
    # Sử dụng sed trực tiếp với mẫu cụ thể
    sed -i.tmp "s/versionCode = [0-9]*/versionCode = $VERSION_CODE/" "$BUILD_GRADLE"
    
    # Kiểm tra nếu thay đổi được áp dụng
    UPDATED_VERSION_CODE=$(grep "versionCode" "$BUILD_GRADLE" | awk -F'=' '{print $2}' | tr -d ' ')
    echo -e "${YELLOW}Version code sau khi cập nhật: $UPDATED_VERSION_CODE${NC}"
    
    if [ "$UPDATED_VERSION_CODE" == "$VERSION_CODE" ]; then
        echo -e "${GREEN}[OK] Đã cập nhật version code thành công!${NC}"
    else
        echo -e "${RED}[LỖI] Không thể cập nhật version code. Kiểm tra lại định dạng file.${NC}"
    fi
fi

# Update version name if provided
if [ ! -z "$VERSION_NAME" ]; then
    echo -e "${YELLOW}Đang cập nhật version name từ $CURRENT_VERSION_NAME thành $VERSION_NAME...${NC}"
    
    # Sử dụng sed trực tiếp với mẫu cụ thể
    sed -i.tmp "s/versionName = \".*\"/versionName = \"$VERSION_NAME\"/" "$BUILD_GRADLE"
    
    # Kiểm tra nếu thay đổi được áp dụng
    UPDATED_VERSION_NAME=$(grep "versionName" "$BUILD_GRADLE" | awk -F'=' '{print $2}' | tr -d ' ')
    echo -e "${YELLOW}Version name sau khi cập nhật: $UPDATED_VERSION_NAME${NC}"
    
fi

# Clean up temporary files
if [ -f "${BUILD_GRADLE}.tmp" ]; then
    rm "${BUILD_GRADLE}.tmp"
fi

# Đọc lại version cuối cùng từ file sau khi cập nhật
FINAL_VERSION_CODE=$(grep "versionCode" "$BUILD_GRADLE" | awk -F'=' '{print $2}' | tr -d ' ')
FINAL_VERSION_NAME=$(grep "versionName" "$BUILD_GRADLE" | awk -F'=' '{print $2}' | tr -d ' ' | tr -d '"')

# Commit thay đổi lên Git nếu có ít nhất một thay đổi thành công
COMMIT_NEEDED=false
if [ ! -z "$VERSION_CODE" ] && [ "$UPDATED_VERSION_CODE" == "$VERSION_CODE" ]; then
    COMMIT_NEEDED=true
fi
if [ ! -z "$VERSION_NAME" ] && [ "$UPDATED_VERSION_NAME" == "\"$VERSION_NAME\"" ]; then # So sánh cả dấu ngoặc kép
    COMMIT_NEEDED=true
fi

if [ "$COMMIT_NEEDED" = true ]; then
    COMMIT_MSG="update: update version android to $FINAL_VERSION_NAME ($FINAL_VERSION_CODE)"
    echo -e "${YELLOW}Đang commit thay đổi lên Git với nội dung: '$COMMIT_MSG'${NC}"
    
    # Đã ở trong thư mục FLUTTER_PROJECT_DIR từ bước checkout

    # Sử dụng đường dẫn tương đối từ FLUTTER_PROJECT_DIR
    git add android/app/build.gradle.kts

    if git commit -m "$COMMIT_MSG"; then
        echo -e "${GREEN}[OK] Đã commit thay đổi thành công!${NC}"
        # Đẩy commit lên remote repository
        echo -e "${YELLOW}Đang đẩy commit lên kho lưu trữ từ xa...${NC}"
        if git push; then
             echo -e "${GREEN}[OK] Đã đẩy commit lên kho lưu trữ từ xa thành công!${NC}"
        else
             echo -e "${RED}[LỖI] Không thể đẩy commit lên kho lưu trữ từ xa. Vui lòng kiểm tra cấu hình Git remote và quyền truy cập.${NC}"
             # Cân nhắc: có nên dừng script ở đây nếu push lỗi không?
             # exit 1 
        fi
    else
        echo -e "${RED}[LỖI] Không thể commit thay đổi. Vui lòng kiểm tra trạng thái Git và đảm bảo không có xung đột.${NC}"
        # Tùy chọn: khôi phục file gốc nếu commit thất bại
        # cp "${BUILD_GRADLE}.bak" "$BUILD_GRADLE"
        # echo -e "${YELLOW}Đã khôi phục file build.gradle.kts từ backup.${NC}"
        # exit 1 # Thoát nếu commit lỗi
    fi
    
    # Quay lại thư mục script ban đầu (tùy chọn, nếu cần)
    # cd "$SCRIPT_DIR" || exit 1
else
     echo -e "${YELLOW}Không có thay đổi phiên bản thành công nào được thực hiện, bỏ qua commit.${NC}"
fi

echo -e "${GREEN}[OK] Hoàn tất quá trình cập nhật version!${NC}"
echo -e "${YELLOW}Kiểm tra kết quả cuối cùng:${NC}"
grep -n "versionCode\\|versionName" "$BUILD_GRADLE" 