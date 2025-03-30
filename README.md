# Monkey Stories CI/CD Pipeline

Pipeline tích hợp và triển khai tự động cho ứng dụng Flutter có tích hợp Unity.

## Cấu trúc dự án

```
.
├── src/                    # Thư mục chứa mã nguồn
│   ├── flutter_project/    # Dự án Flutter
│   └── unity_project/      # Dự án Unity
├── artifacts/              # Thư mục chứa sản phẩm build
│   ├── android/            # Các file APK và AAB cho Android
│   └── ios/                # Các file IPA cho iOS
├── logs/                   # Thư mục chứa log
├── ci/                     # Thư mục chứa các script CI/CD
│   ├── scripts/
│   │   ├── flutter/        # Scripts cho Flutter
│   │   ├── git/            # Scripts cho Git
│   │   ├── unity_export_module.sh
│   │   └── unity_switch_platform.sh
│   ├── config/             # Cấu hình CI/CD
│   └── templates/          # Templates cho CI/CD
├── tools/                  # Công cụ và tiện ích
└── run_ci.sh               # Script chính để chạy CI/CD
```

## Yêu cầu hệ thống

- Flutter SDK
- Unity (phiên bản được chỉ định trong script)
- Git
- Bash shell
- Android SDK (cho build Android)
- Xcode (cho build iOS, chỉ trên macOS)

## Sử dụng các lệnh CI/CD

### 1. Script chính (run_ci.sh)

```bash
# Build mặc định (Android test APK)
./run_ci.sh

# Chỉ định nền tảng
./run_ci.sh --platform android
./run_ci.sh --platform ios

# Chỉ định loại build (test hoặc release)
./run_ci.sh --build-type test
./run_ci.sh --build-type release

# Chỉ định branch
./run_ci.sh --flutter-branch develop --unity-branch feature/new-feature

# Kết hợp các tham số
./run_ci.sh --platform android --build-type release --flutter-branch main --unity-branch main
```

### 2. Các tham số của run_ci.sh

| Tham số              | Mô tả                           | Giá trị mặc định |
| -------------------- | ------------------------------- | ---------------- |
| -p, --platform       | Nền tảng mục tiêu (android/ios) | android          |
| -b, --build-type     | Loại build (test/release)       | test             |
| -f, --flutter-branch | Branch của dự án Flutter        | main             |
| -t, --unity-branch   | Branch của dự án Unity          | main             |
| -u, --unity          | Phiên bản Unity                 | 2022.3.57f1      |
| -h, --help           | Hiển thị trợ giúp               | -                |

### 3. Các script riêng biệt

#### Unity

```bash
# Chuyển đổi platform Unity
./ci/scripts/unity_switch_platform.sh android
./ci/scripts/unity_switch_platform.sh ios

# Xuất Unity module
./ci/scripts/unity_export_module.sh android
./ci/scripts/unity_export_module.sh ios
```

#### Flutter

```bash
# Build Android (test/release)
./ci/scripts/flutter/build_android.sh test
./ci/scripts/flutter/build_android.sh release
```

#### Git

```bash
# Checkout branch (Flutter branch, Unity branch)
./ci/scripts/git/checkout_branch.sh main main
./ci/scripts/git/checkout_branch.sh develop feature/new-ui
```

## Các sản phẩm build

### Android

- **Test build**: `artifacts/android/app-debug.apk`
- **Release build**:
  - APK: `artifacts/android/app-release.apk`
  - AAB: `artifacts/android/app-release.aab`

### iOS (chưa triển khai đầy đủ)

- IPA: `artifacts/ios/app-release.ipa`

## Quy trình CI/CD

1. Checkout đúng branch cho Flutter và Unity
2. Kiểm tra môi trường (Unity, Flutter)
3. Chuyển đổi Unity platform (Android/iOS)
4. Xuất Unity module
5. Build ứng dụng Flutter
6. Thu thập sản phẩm build vào thư mục artifacts
