#!/usr/bin/env bash
set -euo pipefail

# Lấy thư mục hiện tại nơi bạn đang đứng chạy lệnh
current_dir="$(pwd)"
output_file="${1:-${current_dir}/all-contents.txt}"

# Kiểm tra và xóa file output cũ nếu có để tránh ghi đè lặp lại
rm -f "$output_file"

# Quét TOÀN BỘ file, trừ đuôi .jar và thư mục .git
find "$current_dir" -type f ! -name "*.jar" ! -name "*.tgz" ! -name "*.env" ! -path "*/.git/*" ! -path "*/.kube/*" | sort | while IFS= read -r file_path; do
      # Lấy đường dẫn tuyệt đối của file
      abs_path="$(readlink -f "$file_path")"
      
      # Bỏ qua chính file script này và file output để không bị ghi vòng lặp
      if [ "$abs_path" = "$(readlink -f "$output_file")" ] || [ "$abs_path" = "$(readlink -f "$0")" ]; then
          continue
      fi

      {
        printf '===== FILE: %s =====\n' "$abs_path"
        cat "$file_path"
        printf '\n===== END FILE: %s =====\n\n' "$abs_path"
      }
done > "$output_file"

echo "Đã in toàn bộ nội dung các file vào: $output_file"
