#!/bin/bash

# -----------------------------------------------------------------------------
# HÀM GỬI THÔNG BÁO
# -----------------------------------------------------------------------------

# Hàm gửi thông báo đến Google Chat
send_google_chat_message() {
    local message_raw="$1"
    # Escape các ký tự JSON đặc biệt trong tin nhắn
    local message_escaped=$(echo "$message_raw" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\n/\\n/g' -e 's/\r/\\r/g' -e 's/\t/\\t/g')

    # !!! THAY THẾ WEBHOOK URL CỦA BẠN VÀO ĐÂY
    local webhook_url="https://chat.googleapis.com/v1/spaces/AAQAjBi7qCY/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=0nUWD7NOCGq67ZDDXXa-Q0QvxImA_yw52UK7F73A8HQ"

    # Gửi tin nhắn
    local response=$(curl -s -w "%{http_code}" -o /tmp/chat_response.txt \
        -X POST "$webhook_url" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"${message_escaped}\"}")

    local body=$(cat /tmp/chat_response.txt)
    
    # Kiểm tra mã phản hồi HTTP
    if [[ "$response" -ne 200 ]]; then
        echo "❌ Lỗi khi gửi đến Google Chat. Mã HTTP: $response"
        echo "Phản hồi API: $body"
        return 1
    fi

    echo "✅ Đã gửi thông báo thành công đến Google Chat!"
    return 0
}

# (MỚI) Hàm gửi thông báo đến Telegram
send_telegram_message() {
    local message_raw="$1"

    # !!! THAY THẾ BOT TOKEN VÀ CHAT ID CỦA BẠN VÀO ĐÂY
    local bot_token="7623162897:AAHLtuVhQ7UC-JX1Nfq4LxFJAtvFzUdf5oM"
    local chat_id="-4742835903"

    # URL API của Telegram
    local webhook_url="https://api.telegram.org/bot${bot_token}/sendMessage"

    # Tạo JSON payload
    # Markdown được bật để giữ nguyên định dạng (*bold*, etc.)
    local json_payload=$(cat <<EOF
{
    "chat_id": "${chat_id}",
    "text": "${message_raw}",
    "parse_mode": "Markdown"
}
EOF
)

    # Gửi tin nhắn
    local response=$(curl -s -w "%{http_code}" -o /tmp/telegram_response.txt \
        -X POST "$webhook_url" \
        -H "Content-Type: application/json" \
        -d "$json_payload")
    
    local body=$(cat /tmp/telegram_response.txt)

    # Kiểm tra mã phản hồi HTTP
    if [[ "$response" -ne 200 ]]; then
        echo "❌ Lỗi khi gửi đến Telegram. Mã HTTP: $response"
        echo "Phản hồi API: $body"
        return 1
    fi

    echo "✅ Đã gửi thông báo thành công đến Telegram!"
    return 0
}

# (MỚI) Hàm chung để gửi đi nhiều kênh
send_notification() {
    local message="$1"
    echo "----------------------------------------"
    echo "Đang gửi thông báo..."
    echo -e "$message"
    echo "----------------------------------------"
    
    # Gửi đến Google Chat
    send_google_chat_message "$message"
    
    # Gửi đến Telegram
    send_telegram_message "$message"
}


# -----------------------------------------------------------------------------
# CÁC HÀM TẠO NỘI DUNG VÀ GỬI ĐI
# Các hàm bên dưới giờ sẽ gọi `send_notification` để gửi đi đồng thời
# -----------------------------------------------------------------------------

# Hàm gửi thông báo bắt đầu build
send_telegram_start() {
    local platform="$1"
    local build_type="$2"
    local flutter_branch="$3"
    local unity_branch="$4"
    
    local message="*Start Build*
    - Platform: ${platform}
    - Build Type: ${build_type}
    - Flutter Branch: ${flutter_branch}
    - Unity Branch: ${unity_branch}"

    send_notification "$message"
}

# Hàm gửi thông báo Unity export
send_telegram_unity_export() {
    local status="$1"
    local platform="$2"
    local build_type="$3"
    local unity_branch="$4"
    local unity_commit="$5"
    
    local emoji=""
    case "$status" in
        "success") emoji="✅";;
        "error") emoji="❌";;
        *) emoji="ℹ️";;
    esac
    
    local message="*Unity Export - ${platform}*
    - Status: ${status}
    - Build Type: ${build_type}
    - Unity Branch: ${unity_branch}
    - Commit: ${unity_commit}"

    send_notification "$message"
}

# Hàm gửi thông báo lỗi
send_telegram_error() {
    local platform="$1"
    local build_type="$2"
    local flutter_branch="$3"
    local flutter_commit="$4"
    local unity_branch="$5"
    local unity_commit="$6"
    local error_message="$7"
    local error_details="$8"
    
    local message="*Build Error*
    - Platform: ${platform}
    - Build Type: ${build_type}
    - Flutter: ${flutter_branch} - ${flutter_commit}
    - Unity: ${unity_branch} - ${unity_commit}
    - Error message: ${error_message}
    - Time: $(date '+%Y-%m-%d %H:%M:%S')"

    send_notification "$message"
}

# Hàm gửi thông báo kết thúc build
send_telegram_finish() {
    local platform="$1"
    local build_type="$2"
    local flutter_branch="$3"
    local flutter_commit="$4"
    local flutter_commit_msg="$5"
    local unity_branch="$6"
    local unity_commit="$7"
    local unity_commit_msg="$8"
    local version_code="$9"
    local version_name="${10}"
    local build_url="${11}"
    
    local message="*Build Success*
    - Platform: ${platform}
    - Build Type: ${build_type}
    - Version: ${version_name} (${version_code})
    - Flutter: ${flutter_branch} - ${flutter_commit} - ${flutter_commit_msg}
    - Unity: ${unity_branch} - ${unity_commit} - ${unity_commit_msg}
    - Time: $(date '+%Y-%m-%d %H:%M:%S')
    - Link tải: ${build_url}"

    send_notification "$message"
}
