const express = require('express');
const pool = require('../config/db');

const router = express.Router();

function toUser(row) {
  return {
    user_id: row.user_id,
    id: String(row.user_id),
    full_name: row.full_name,
    fullName: row.full_name,
    email: row.email,
    phone: row.phone,
    address: row.address,
    role_id: row.role_id,
    role_name: row.role_name,
    role: row.role_name,
    points: row.points,
    membership_code: row.membership_code,
    status: row.status,
    created_at: row.created_at,
  };
}

router.get('/', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT u.*, r.role_name
       FROM users u
       JOIN roles r ON r.role_id = u.role_id
       ORDER BY u.user_id DESC`
    );
    res.json({ success: true, data: rows.map(toUser) });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi lấy người dùng', error: error.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { full_name, fullName, email, phone, password, address, role_name, role } = req.body;
    const name = full_name || fullName;
    const roleName = role_name || role || 'employee';

    if (!name || !email || !password) {
      return res.status(400).json({ success: false, message: 'Vui lòng nhập full_name, email, password' });
    }

    const [roles] = await pool.execute('SELECT role_id FROM roles WHERE role_name = ?', [roleName]);
    if (roles.length === 0) {
      return res.status(400).json({ success: false, message: 'Role không hợp lệ' });
    }

    const [result] = await pool.execute(
      `INSERT INTO users (full_name, email, phone, password, address, role_id)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [name, email, phone || null, password, address || null, roles[0].role_id]
    );
    const [rows] = await pool.execute(
      `SELECT u.*, r.role_name FROM users u JOIN roles r ON r.role_id = u.role_id WHERE u.user_id = ?`,
      [result.insertId]
    );
    res.status(201).json({ success: true, message: 'Đã thêm người dùng', data: toUser(rows[0]) });
  } catch (error) {
    const status = error.code === 'ER_DUP_ENTRY' ? 409 : 500;
    res.status(status).json({ success: false, message: 'Lỗi thêm người dùng', error: error.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const { full_name, fullName, email, phone, password, address, role_name, role, status } = req.body;
    let roleId = null;
    if (role_name || role) {
      const [roles] = await pool.execute('SELECT role_id FROM roles WHERE role_name = ?', [role_name || role]);
      if (roles.length === 0) {
        return res.status(400).json({ success: false, message: 'Role không hợp lệ' });
      }
      roleId = roles[0].role_id;
    }

    await pool.execute(
      `UPDATE users
       SET full_name = COALESCE(?, full_name),
           email = COALESCE(?, email),
           phone = ?,
           password = COALESCE(?, password),
           address = ?,
           role_id = COALESCE(?, role_id),
           status = COALESCE(?, status)
       WHERE user_id = ?`,
      [
        full_name || fullName || null,
        email || null,
        phone ?? null,
        password || null,
        address ?? null,
        roleId,
        status || null,
        req.params.id,
      ]
    );

    const [rows] = await pool.execute(
      `SELECT u.*, r.role_name FROM users u JOIN roles r ON r.role_id = u.role_id WHERE u.user_id = ?`,
      [req.params.id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy người dùng' });
    }
    res.json({ success: true, message: 'Đã cập nhật người dùng', data: toUser(rows[0]) });
  } catch (error) {
    const status = error.code === 'ER_DUP_ENTRY' ? 409 : 500;
    res.status(status).json({ success: false, message: 'Lỗi cập nhật người dùng', error: error.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    await pool.execute("UPDATE users SET status = 'inactive' WHERE user_id = ?", [req.params.id]);
    res.json({ success: true, message: 'Đã khóa người dùng' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi xóa người dùng', error: error.message });
  }
});

module.exports = router;
