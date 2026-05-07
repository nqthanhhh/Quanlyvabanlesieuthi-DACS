-- NOTE (SAFE INIT):
-- File này được thiết kế để import nhiều lần mà KHÔNG làm mất dữ liệu hiện có.
-- Nếu bạn muốn xoá sạch dữ liệu và tạo lại từ đầu, hãy chạy `database_reset.sql` trước.

CREATE DATABASE IF NOT EXISTS mini_supermarket
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE mini_supermarket;

-- Không DROP TABLE ở đây để tránh mất dữ liệu khi import lại.

CREATE TABLE IF NOT EXISTS roles (
  role_id INT AUTO_INCREMENT PRIMARY KEY,
  role_name VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS users (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(100) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE,
  phone VARCHAR(20) UNIQUE,
  password VARCHAR(255) NOT NULL,
  address VARCHAR(255),
  role_id INT NOT NULL,
  points INT DEFAULT 0,
  membership_code VARCHAR(50) UNIQUE,
  status VARCHAR(20) DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_users_roles
    FOREIGN KEY (role_id)
    REFERENCES roles(role_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS categories (
  category_id INT AUTO_INCREMENT PRIMARY KEY,
  category_name VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS products (
  product_id INT AUTO_INCREMENT PRIMARY KEY,
  product_name VARCHAR(150) NOT NULL,
  barcode VARCHAR(50) NOT NULL UNIQUE,
  description TEXT,
  image_url VARCHAR(255),
  price DECIMAL(10,2) NOT NULL,
  unit VARCHAR(50) NOT NULL DEFAULT 'sp',
  stock INT NOT NULL DEFAULT 0,
  min_stock INT DEFAULT 10,
  category_id INT NOT NULL,
  status VARCHAR(20) DEFAULT 'active',

  CONSTRAINT fk_products_categories
    FOREIGN KEY (category_id)
    REFERENCES categories(category_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS inventory_items (
  inventory_item_id INT AUTO_INCREMENT PRIMARY KEY,
  barcode VARCHAR(50) NOT NULL UNIQUE,
  item_name VARCHAR(150) NOT NULL,
  image_url VARCHAR(255),
  price DECIMAL(10,2) NOT NULL,
  import_price DECIMAL(10,2) NULL,
  unit VARCHAR(50) NOT NULL DEFAULT 'sp',
  stock INT NOT NULL DEFAULT 0,
  status VARCHAR(20) DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS carts (
  cart_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_carts_users
    FOREIGN KEY (user_id)
    REFERENCES users(user_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cart_items (
  cart_item_id INT AUTO_INCREMENT PRIMARY KEY,
  cart_id INT NOT NULL,
  product_id INT NOT NULL,
  quantity INT NOT NULL DEFAULT 1,

  CONSTRAINT fk_cart_items_carts
    FOREIGN KEY (cart_id)
    REFERENCES carts(cart_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,

  CONSTRAINT fk_cart_items_products
    FOREIGN KEY (product_id)
    REFERENCES products(product_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS orders (
  order_id INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT,
  employee_id INT,
  order_type VARCHAR(30) NOT NULL,
  total_amount DECIMAL(10,2) NOT NULL,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  final_amount DECIMAL(10,2) NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  payment_status VARCHAR(50) DEFAULT 'unpaid',
  shipping_address VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id)
    REFERENCES users(user_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL,

  CONSTRAINT fk_orders_employee
    FOREIGN KEY (employee_id)
    REFERENCES users(user_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_items (
  order_item_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  product_id INT NOT NULL,
  quantity INT NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL,

  CONSTRAINT fk_order_items_orders
    FOREIGN KEY (order_id)
    REFERENCES orders(order_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,

  CONSTRAINT fk_order_items_products
    FOREIGN KEY (product_id)
    REFERENCES products(product_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payments (
  payment_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  method VARCHAR(50) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  status VARCHAR(50) NOT NULL,
  qr_content VARCHAR(255),
  paid_at TIMESTAMP NULL DEFAULT NULL,

  CONSTRAINT fk_payments_orders
    FOREIGN KEY (order_id)
    REFERENCES orders(order_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS invoices (
  invoice_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL UNIQUE,
  issued_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  total DECIMAL(10,2) NOT NULL,

  CONSTRAINT fk_invoices_orders
    FOREIGN KEY (order_id)
    REFERENCES orders(order_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS inventory_logs (
  log_id INT AUTO_INCREMENT PRIMARY KEY,
  inventory_item_id INT NOT NULL,
  product_id INT,
  employee_id INT NOT NULL,
  action VARCHAR(20) NOT NULL,
  quantity INT NOT NULL,
  import_price DECIMAL(10,2) NULL,
  note VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_inventory_logs_items
    FOREIGN KEY (inventory_item_id)
    REFERENCES inventory_items(inventory_item_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT fk_inventory_logs_products
    FOREIGN KEY (product_id)
    REFERENCES products(product_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT fk_inventory_logs_employee
    FOREIGN KEY (employee_id)
    REFERENCES users(user_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS discount_codes (
  discount_id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  discount_type VARCHAR(20) NOT NULL,
  discount_value DECIMAL(10,2) NOT NULL,
  start_date DATE,
  end_date DATE,
  status VARCHAR(20) DEFAULT 'active'
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_discounts (
  order_discount_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  discount_id INT NOT NULL,
  discount_amount DECIMAL(10,2) NOT NULL,

  CONSTRAINT fk_order_discounts_orders
    FOREIGN KEY (order_id)
    REFERENCES orders(order_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,

  CONSTRAINT fk_order_discounts_discount_codes
    FOREIGN KEY (discount_id)
    REFERENCES discount_codes(discount_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reviews (
  review_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  product_id INT NOT NULL,
  rating INT NOT NULL,
  comment TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_reviews_users
    FOREIGN KEY (user_id)
    REFERENCES users(user_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,

  CONSTRAINT fk_reviews_products
    FOREIGN KEY (product_id)
    REFERENCES products(product_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS loyalty_transactions (
  loyalty_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  order_id INT,
  points_change INT NOT NULL,
  type VARCHAR(20) NOT NULL,
  note VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_loyalty_transactions_users
    FOREIGN KEY (user_id)
    REFERENCES users(user_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,

  CONSTRAINT fk_loyalty_transactions_orders
    FOREIGN KEY (order_id)
    REFERENCES orders(order_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS work_shifts (
  shift_id INT AUTO_INCREMENT PRIMARY KEY,
  employee_id INT NOT NULL,
  shift_date DATE NOT NULL,
  start_time TIME,
  end_time TIME,
  note VARCHAR(255),

  CONSTRAINT fk_work_shifts_employee
    FOREIGN KEY (employee_id)
    REFERENCES users(user_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notifications (
  notification_id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(150) NOT NULL,
  message VARCHAR(255) NOT NULL,
  type VARCHAR(50),
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT IGNORE INTO roles(role_name)
VALUES
('customer'),
('employee'),
('admin');

INSERT IGNORE INTO users(full_name, email, phone, password, address, role_id, status)
VALUES
('Admin', 'admin@gmail.com', '0900000001', 'admin123', 'Tai khoan quan tri', (SELECT role_id FROM roles WHERE role_name = 'admin'), 'active'),
('Nhan vien', 'employee@gmail.com', '0900000002', 'employee123', 'Tai khoan nhan vien', (SELECT role_id FROM roles WHERE role_name = 'employee'), 'active');

INSERT IGNORE INTO categories(category_name)
VALUES
('Đồ uống'),
('Đồ ăn nhanh'),
('Gia vị'),
('Sữa'),
('Bánh kẹo'),
('Đồ gia dụng');

INSERT IGNORE INTO products (
  product_name,
  barcode,
  description,
  image_url,
  price,
  unit,
  stock,
  min_stock,
  category_id,
  status
)
VALUES
('Coca Cola lon 330ml', '893000000001', 'Nước ngọt có gas', '', 10000, 'lon', 20, 10, 1, 'active'),
('Pepsi lon 330ml', '893000000002', 'Nước ngọt có gas', '', 10000, 'lon', 20, 10, 1, 'active'),
('Mì Hảo Hảo tôm chua cay', '893000000003', 'Mì ăn liền', '', 4500, 'gói', 40, 20, 2, 'active'),
('Sữa Vinamilk 180ml', '893000000004', 'Sữa hộp', '', 8000, 'hộp', 20, 10, 4, 'active'),
('Bánh Oreo', '893000000005', 'Bánh quy socola', '', 12000, 'gói', 20, 10, 5, 'active');

-- Seed kho (inventory_items): tồn trong kho (warehouse).
-- Seed products.stock: tồn trên kệ/tồn bán (shelf) dùng cho màn hình bán hàng.
INSERT IGNORE INTO inventory_items (
  barcode,
  item_name,
  image_url,
  price,
  import_price,
  unit,
  stock,
  status
)
VALUES
('893000000001', 'Coca Cola lon 330ml', '', 10000, NULL, 'lon', 80, 'active'),
('893000000002', 'Pepsi lon 330ml', '', 10000, NULL, 'lon', 80, 'active'),
('893000000003', 'Mì Hảo Hảo tôm chua cay', '', 4500, NULL, 'gói', 160, 'active'),
('893000000004', 'Sữa Vinamilk 180ml', '', 8000, NULL, 'hộp', 60, 'active'),
('893000000005', 'Bánh Oreo', '', 12000, NULL, 'gói', 40, 'active');
