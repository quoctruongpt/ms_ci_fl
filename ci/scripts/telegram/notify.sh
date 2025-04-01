#!/bin/bash

# Hàm gửi thông báo
send_telegram_message() {
    local message="$1"
    # Chuyển đổi \n thành %0A cho URL encoding
    message=$(echo "$message" | sed 's/\\n/%0A/g')
    local response=$(curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=HTML")
    
    # Kiểm tra lỗi
    if [[ $? -ne 0 ]]; then
        echo "Lỗi khi gửi thông báo Telegram: $response" >&2
        return 1
    fi
    
    # Kiểm tra response từ API
    if echo "$response" | grep -q '"ok":false'; then
        echo "Lỗi API Telegram: $response" >&2
        return 1
    fi
    
    echo "Gửi thông báo thành công!"
    return 0
}

# Hàm gửi thông báo bắt đầu build
send_telegram_start() {
    local platform="$1"
    local build_type="$2"
    local flutter_branch="$3"
    local flutter_commit="$4"
    local flutter_commit_msg="$5"
    local unity_branch="$6"
    local unity_commit="$7"
    local unity_commit_msg="$8"
    
    local message="🚀 <b>Bắt đầu Build</b>\n\n"
    message+="Platform: ${platform}\n"
    message+="Build Type: ${build_type}\n"
    message+="Flutter Branch: ${flutter_branch} - ${flutter_commit} (${flutter_commit_msg})\n"
    message+="Unity Branch: ${unity_branch} - ${unity_commit} (${unity_commit_msg})\n"
    message+="Thời gian: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_telegram_message "$message"
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
    esac
    
    local message="${emoji} <b>Unity Export ${platform}</b>\n"
    message+="Trạng thái: ${status}\n"
    message+="Thời gian: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_telegram_message "$message"
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
    
    local message="❌ <b>Build Lỗi</b>\n\n"
    message+="Platform: ${platform}\n"
    message+="Build Type: ${build_type}\n"
    message+="Flutter Branch: ${flutter_branch} - ${flutter_commit}\n"
    message+="Unity Branch: ${unity_branch} - ${unity_commit}\n"
    message+="Lỗi: ${error_message}\n"
    if [ ! -z "$error_details" ]; then
        message+="Chi tiết: ${error_details}\n"
    fi
    message+="Thời gian: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_telegram_message "$message"
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
    
    local message="🎉 <b>Build Hoàn Tất</b>\n\n"
    message+="Platform: ${platform}\n"
    message+="Build Type: ${build_type}\n"
    message+="Version: ${version_name} ${version_code}\n"
    if [ ! -z "$build_url" ]; then
        message+="Link tải: ${build_url}\n"
    fi
    message+="Thời gian: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_telegram_message "$message"
} 