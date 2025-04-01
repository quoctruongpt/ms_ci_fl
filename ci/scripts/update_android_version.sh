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

# Check if the build.gradle.kts file exists
if [ ! -f "$BUILD_GRADLE" ]; then
    echo -e "${RED}[LỖI] Không tìm thấy file build.gradle.kts tại: $BUILD_GRADLE${NC}"
    exit 1
fi

# Function to display help message
show_help() {
    echo "Cách sử dụng: $0 [options]"
    echo ""
    echo "Tùy chọn:"
    echo "  -c, --code VERSION_CODE    Đặt version code mới"
    echo "  -n, --name VERSION_NAME    Đặt version name mới"
    echo "  -k, --keep-backup          Giữ lại file backup sau khi cập nhật"
    echo "  -h, --help                 Hiển thị trợ giúp này"
    echo ""
    echo "Ví dụ:"
    echo "  $0 -c 2 -n 4.0.1"
    echo "  $0 --code 2 --name 4.0.1 --keep-backup"
}

# Parse command line arguments
VERSION_CODE=""
VERSION_NAME=""
KEEP_BACKUP=false

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
        -k|--keep-backup)
            KEEP_BACKUP=true
            shift
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

# Backup the original file
cp "$BUILD_GRADLE" "${BUILD_GRADLE}.bak"
echo -e "${YELLOW}Đã tạo file backup tại ${BUILD_GRADLE}.bak${NC}"

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
    sed -i.tmp "s/versionName = [0-9.]*/versionName = $VERSION_NAME/" "$BUILD_GRADLE"
    
    # Kiểm tra nếu thay đổi được áp dụng
    UPDATED_VERSION_NAME=$(grep "versionName" "$BUILD_GRADLE" | awk -F'=' '{print $2}' | tr -d ' ')
    echo -e "${YELLOW}Version name sau khi cập nhật: $UPDATED_VERSION_NAME${NC}"
    
    if [ "$UPDATED_VERSION_NAME" == "$VERSION_NAME" ]; then
        echo -e "${GREEN}[OK] Đã cập nhật version name thành công!${NC}"
    else
        echo -e "${RED}[LỖI] Không thể cập nhật version name. Kiểm tra lại định dạng file.${NC}"
    fi
fi

# Clean up temporary files
if [ -f "${BUILD_GRADLE}.tmp" ]; then
    rm "${BUILD_GRADLE}.tmp"
fi

echo -e "${GREEN}[OK] Hoàn tất quá trình cập nhật version!${NC}"
echo -e "${YELLOW}Kiểm tra kết quả cuối cùng:${NC}"
grep -n "versionCode\|versionName" "$BUILD_GRADLE"

# Xử lý file backup
if [ "$KEEP_BACKUP" = false ]; then
    if [ -f "${BUILD_GRADLE}.bak" ]; then
        rm "${BUILD_GRADLE}.bak"
        echo -e "${GREEN}[OK] Đã xóa file backup.${NC}"
    fi
else
    echo -e "${YELLOW}Đã giữ lại file backup tại ${BUILD_GRADLE}.bak${NC}"
fi 