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
├── database.sql         # File CSDL MySQL chung để import
├── pubspec.yaml         # Cấu hình Flutter
└── README.md
```

## Tải code về máy

Nếu chưa có project trên máy:

```bash
git clone https://github.com/nqthanhhh/Quanlyvabanlesieuthi-DACS.git
cd Quanlyvabanlesieuthi-DACS
```

Nếu đã có project từ trước, kéo code mới nhất:

```bash
git checkout main
git pull origin main
```

## Mở project bằng công cụ nào

Mở thư mục gốc project bằng Android Studio để chạy và sửa Flutter frontend:

```text
lib/
android/
ios/
pubspec.yaml
```

File frontend cần chú ý khi đổi địa chỉ API backend:

```text
lib/services/api_service.dart
```

Mở thư mục backend bằng Visual Studio Code để chạy và sửa Node.js Express:

```text
backend_nodejs/
```

Các file backend chính:

```text
backend_nodejs/src/server.js
backend_nodejs/src/config/db.js
backend_nodejs/src/routes/
backend_nodejs/package.json
backend_nodejs/.env
backend_nodejs/.env.example
backend_nodejs/database.sql
database.sql
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
mysql -u your_mysql_user -p < database.sql
```

File `database.sql` nằm ở gốc project để dễ thấy. Trong `backend_nodejs/` cũng có bản `backend_nodejs/database.sql` cho phần backend.
