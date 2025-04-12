#!/bin/bash

# Script chuyển đổi git branch
# =============================

# Màu sắc cho output
RED='🔴'
GREEN='🟢'
YELLOW='🟡'
NC='' # No Color

# Xác định đường dẫn gốc nếu chưa được truyền vào
if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
fi

# Hàm checkout branch
checkout_branch() {
  local project_type="$1"  # 'flutter' hoặc 'unity'
  local branch="$2"
  local project_dir="$3"

  echo -e "${YELLOW}Chuyển đổi $project_type branch sang '$branch'...${NC}"

  # Kiểm tra git repository
  if [[ ! -d "$project_dir/.git" ]]; then
    echo -e "${RED}[LỖI] Không tìm thấy git repository cho dự án $project_type tại: $project_dir${NC}"
    return 1
  fi

  # Lưu thư mục hiện tại
  local current_dir=$(pwd)
  
  # Di chuyển đến thư mục dự án
  cd "$project_dir"

  echo "Clean git"
  git reset --hard
  git clean -f -d

  # Fetch mới nhất từ origin
  echo -e "${YELLOW}Đang fetch từ remote...${NC}"
  git fetch origin

  # Kiểm tra xem branch có tồn tại không
  if git show-ref --quiet "refs/remotes/origin/$branch"; then
    # Thử checkout branch hiện có, nếu không có thì tạo mới từ origin
    if git checkout "$branch" 2>/dev/null; then
      echo -e "${GREEN}Đã checkout branch $branch${NC}"
    else
      echo -e "${YELLOW}Branch $branch chưa tồn tại cục bộ, đang tạo mới từ origin...${NC}"
      if git checkout -b "$branch" "origin/$branch"; then
        echo -e "${GREEN}Đã tạo và checkout branch mới $branch từ origin/$branch${NC}"
      else
        echo -e "${RED}[LỖI] Không thể checkout hoặc tạo branch: $branch${NC}"
        cd "$current_dir"
        return 1
      fi
    fi

    # Pull mới nhất từ origin
    echo -e "${YELLOW}Đang pull mới nhất từ remote...${NC}"
    if git pull origin "$branch"; then
      echo -e "${GREEN}Đã cập nhật $project_type branch: $branch${NC}"
    else
      echo -e "${RED}[LỖI] Không thể pull từ origin/$branch${NC}"
      cd "$current_dir"
      return 1
    fi
  else
    echo -e "${RED}[LỖI] $project_type branch không tồn tại trên remote: $branch${NC}"
    cd "$current_dir"
    return 1
  fi

  # Trở về thư mục ban đầu
  cd "$current_dir"
  return 0
}

# Hàm chính
main() {
  local flutter_branch="$1"
  local unity_branch="$2"
  
  # Đường dẫn đến các dự án
  local flutter_project_dir="${ROOT_DIR}/src/flutter_project"
  local unity_project_dir="${ROOT_DIR}/src/unity_project"

  # Checkout Flutter branch
  checkout_branch "Flutter" "$flutter_branch" "$flutter_project_dir"
  if [[ $? -ne 0 ]]; then
    exit 1
  fi

  # Checkout Unity branch
  checkout_branch "Unity" "$unity_branch" "$unity_project_dir"
  if [[ $? -ne 0 ]]; then
    exit 1
  fi

  echo -e "${GREEN}[OK] Tất cả branch đã được checkout thành công.${NC}"
  return 0
}

# Kiểm tra xem script có được gọi trực tiếp không (không phải được source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Các giá trị mặc định
  FLUTTER_BRANCH=${1:-"main"}
  UNITY_BRANCH=${2:-"main"}

  # Hiển thị thông tin
  echo "=== CHUYỂN ĐỔI GIT BRANCH ==="
  echo "Flutter branch: $FLUTTER_BRANCH"
  echo "Unity branch: $UNITY_BRANCH"

  # Chạy hàm chính
  main "$FLUTTER_BRANCH" "$UNITY_BRANCH"
  exit $?
fi 