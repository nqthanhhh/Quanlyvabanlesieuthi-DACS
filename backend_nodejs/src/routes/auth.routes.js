const express = require('express');
const pool = require('../config/db');

const router = express.Router();

// REGISTER
router.post('/register', async (req, res) => {
  try {
    const { full_name, email, phone, password, address } = req.body;

    if (!full_name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng nhập full_name, email, password',
      });
    }

    // Lấy role customer
    const [roles] = await pool.execute(
      "SELECT role_id FROM roles WHERE role_name = 'customer'"
    );

    if (roles.length === 0) {
      return res.status(500).json({
        success: false,
        message: "Chưa có role 'customer' trong database",
      });
    }

    // Kiểm tra email đã tồn tại chưa
    const [existingEmail] = await pool.execute(
      'SELECT user_id FROM users WHERE email = ?',
      [email]
    );

    if (existingEmail.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'Email đã tồn tại',
      });
    }

    // Kiểm tra phone đã tồn tại chưa (nếu có nhập)
    if (phone) {
      const [existingPhone] = await pool.execute(
        'SELECT user_id FROM users WHERE phone = ?',
        [phone]
      );

      if (existingPhone.length > 0) {
        return res.status(409).json({
          success: false,
          message: 'Số điện thoại đã tồn tại',
        });
      }
    }

    const role_id = roles[0].role_id;

    // Tạo tài khoản customer
    const [result] = await pool.execute(
      `INSERT INTO users
      (full_name, email, phone, password, address, role_id)
      VALUES (?, ?, ?, ?, ?, ?)`,
      [
        full_name,
        email,
        phone || null,
        password,
        address || null,
        role_id,
      ]
    );

    // Lấy user vừa tạo
    const [newUsers] = await pool.execute(
      `SELECT u.user_id, u.full_name, u.email, u.phone,
              u.address, u.points, u.membership_code,
              u.status, u.created_at, r.role_name
       FROM users u
       JOIN roles r ON r.role_id = u.role_id
       WHERE u.user_id = ?`,
      [result.insertId]
    );

    res.json({
      success: true,
      message: 'Đăng ký thành công',
      user: newUsers[0],
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Lỗi đăng ký',
      error: error.message,
    });
  }
});

// LOGIN
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng nhập email và mật khẩu',
      });
    }

    const [users] = await pool.execute(
      `SELECT u.user_id, u.full_name, u.email, u.phone,
              u.address, u.points, u.membership_code,
              u.status, u.created_at, r.role_name
       FROM users u
       JOIN roles r ON r.role_id = u.role_id
       WHERE u.email = ?
       AND u.password = ?
       AND u.status = 'active'`,
      [email, password]
    );

    if (users.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Sai email hoặc mật khẩu',
      });
    }

    res.json({
      success: true,
      message: 'Đăng nhập thành công',
      user: users[0],
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Lỗi đăng nhập',
      error: error.message,
    });
  }
});

module.exports = router;