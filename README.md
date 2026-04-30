# Ứng dụng quản lý/bán hàng siêu thị

## Công nghệ hiện tại

- Frontend: Flutter
- Backend: Node.js Express
- Database: MySQL

Dự án hiện không còn dùng Firebase làm database chính. Dữ liệu chính được xử lý qua backend Node.js Express và lưu trong MySQL.

## Cấu trúc thư mục

```text
.
├── lib/                 # Mã nguồn Flutter
├── android/             # Project Android
├── ios/                 # Project iOS
├── web/                 # Project Web Flutter
├── backend_nodejs/      # Backend Node.js Express
├── pubspec.yaml         # Cấu hình Flutter
└── README.md
```

## Cách chạy backend

```bash
cd backend_nodejs
npm install
npm start
```

## Cách chạy frontend

```bash
flutter pub get
flutter run
```

## Cấu hình file .env

Backend cần file `.env` để cấu hình kết nối MySQL và các biến môi trường khác. File `.env` thật không được commit lên Git vì có thể chứa mật khẩu, token hoặc API key.

Tạo file `.env` từ file mẫu:

```bash
cp backend_nodejs/.env.example backend_nodejs/.env
```

Sau đó điền giá trị phù hợp, ví dụ:

```env
DB_HOST=localhost
DB_PORT=3306
DB_USER=your_mysql_user
DB_PASSWORD=your_mysql_password
DB_NAME=your_database_name
```

## Import MySQL database

Nếu repo có file `.sql`, import database bằng lệnh tương tự:

```bash
mysql -u your_mysql_user -p < backend_nodejs/database.sql
```

Nếu chưa có file `.sql`, hãy tạo database MySQL thủ công hoặc import từ bản sao database local trước khi chạy backend.
