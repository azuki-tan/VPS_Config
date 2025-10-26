#!/bin/bash

# Hiển thị menu lựa chọn
clear
echo "Chọn thao tác:"
echo "1. Nén (Compress)"
echo "2. Giải nén (Extract)"
read -p "Nhập lựa chọn (1 hoặc 2): " choice

# Xử lý lựa chọn
case $choice in
    1)
        # Nén (Compress)
        read -p "Đường dẫn thư mục cần nén: " source_dir
        read -p "Tên file .tar.gz (ví dụ: archive.tar.gz): " archive_name
        read -p "Đường dẫn lưu file .tar.gz: " dest_dir

        # Kiểm tra đường dẫn thư mục nguồn tồn tại
        if [ ! -d "$source_dir" ]; then
            echo "Lỗi: Đường dẫn thư mục nguồn không tồn tại."
            exit 1
        fi

        # Kiểm tra đường dẫn thư mục đích tồn tại và tạo nếu cần
        if [ ! -d "$dest_dir" ]; then
            mkdir -p "$dest_dir"
        fi

        # Nén với mức nén cao (-9)
        tar -czvf "$dest_dir/$archive_name" -C "$source_dir" .
        echo "Nén thành công file $dest_dir/$archive_name"
        ;;
    2)
        # Giải nén (Extract)
        read -p "Đường dẫn file .tar.gz: " archive_path
        read -p "Đường dẫn cần giải nén: " extract_dir

        # Kiểm tra file .tar.gz tồn tại
        if [ ! -f "$archive_path" ]; then
            echo "Lỗi: File .tar.gz không tồn tại."
            exit 1
        fi

        # Kiểm tra đường dẫn thư mục giải nén tồn tại và tạo nếu cần
        if [ ! -d "$extract_dir" ]; then
            mkdir -p "$extract_dir"
        fi

        # Giải nén
        tar -xzvf "$archive_path" -C "$extract_dir"
        echo "Giải nén thành công vào thư mục $extract_dir"
        ;;
    *)
        # Lựa chọn không hợp lệ
        echo "Lựa chọn không hợp lệ."
        exit 1
        ;;
esac

exit 0