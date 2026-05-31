const express = require('express');
const pool = require('../config/db');

const router = express.Router();

function normalizePhone(phone) {
  return String(phone || '').replace(/\D/g, '');
}

function calculateTierMultiplier(currentPoints) {
  if (currentPoints >= 1000) return 1.5;
  if (currentPoints >= 500) return 1.2;
  return 1;
}

function calculatePoints(amount, currentPoints) {
  const basePoints = Math.floor(Number(amount || 0) / 10000);
  return Math.max(0, Math.floor(basePoints * calculateTierMultiplier(currentPoints)));
}

async function getCustomerRoleId(connection) {
  const [roles] = await connection.execute(
    "SELECT role_id FROM roles WHERE role_name = 'customer' LIMIT 1",
  );
  if (roles.length === 0) {
    throw new Error("Chưa có role 'customer' trong database");
  }
  return roles[0].role_id;
}

router.post('/add', async (req, res) => {
  const customerName = String(req.body.customerName || req.body.customer_name || '').trim();
  const phone = normalizePhone(req.body.phone);
  const amount = Number(req.body.amount || 0);
  const employeeId = Number(req.body.employeeId || req.body.employee_id || 0) || null;
  const orderId = Number(req.body.orderId || req.body.order_id || 0) || null;

  if (!customerName) {
    return res.status(400).json({ success: false, message: 'Vui lòng nhập tên khách hàng' });
  }
  if (phone.length < 8 || phone.length > 15) {
    return res.status(400).json({ success: false, message: 'Số điện thoại không hợp lệ' });
  }
  if (amount <= 0) {
    return res.status(400).json({ success: false, message: 'Số tiền tích điểm không hợp lệ' });
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const customerRoleId = await getCustomerRoleId(connection);

    const [existing] = await connection.execute(
      `SELECT u.user_id, u.full_name, u.phone, u.points, r.role_name
       FROM users u
       JOIN roles r ON r.role_id = u.role_id
       WHERE u.phone = ?
       LIMIT 1
       FOR UPDATE`,
      [phone],
    );

    let customer;
    if (existing.length > 0) {
      customer = existing[0];
      if (customer.role_name !== 'customer') {
        await connection.rollback();
        return res.status(409).json({
          success: false,
          message: 'Số điện thoại này đang thuộc tài khoản không phải khách hàng',
        });
      }
      if (customerName && customer.full_name !== customerName) {
        await connection.execute(
          'UPDATE users SET full_name = ? WHERE user_id = ?',
          [customerName, customer.user_id],
        );
      }
    } else {
      const syntheticEmail = `offline_${phone}@smartpos.local`;
      const membershipCode = `MB${Date.now()}${phone.slice(-4)}`;
      const [result] = await connection.execute(
        `INSERT INTO users
          (full_name, email, phone, password, role_id, points, membership_code, status)
         VALUES (?, ?, ?, ?, ?, 0, ?, 'active')`,
        [customerName, syntheticEmail, phone, 'offline_customer', customerRoleId, membershipCode],
      );
      customer = {
        user_id: result.insertId,
        full_name: customerName,
        phone,
        points: 0,
        role_name: 'customer',
      };
    }

    const currentPoints = Number(customer.points || 0);
    const pointsAdded = calculatePoints(amount, currentPoints);
    const totalPoints = currentPoints + pointsAdded;

    await connection.execute(
      'UPDATE users SET points = ? WHERE user_id = ?',
      [totalPoints, customer.user_id],
    );
    await connection.execute(
      `INSERT INTO loyalty_transactions (user_id, order_id, points_change, type, note)
       VALUES (?, ?, ?, 'earn', ?)`,
      [
        customer.user_id,
        orderId,
        pointsAdded,
        `POS tích điểm ${amount.toLocaleString('vi-VN')} VND${employeeId ? ` bởi NV ${employeeId}` : ''}`,
      ],
    );

    await connection.commit();
    return res.json({
      success: true,
      message: 'Đã tích điểm khách hàng',
      data: {
        customerId: customer.user_id,
        customerName,
        phone,
        pointsAdded,
        totalPoints,
      },
    });
  } catch (error) {
    await connection.rollback();
    const status = error.code === 'ER_DUP_ENTRY' ? 409 : 500;
    return res.status(status).json({
      success: false,
      message: 'Lỗi tích điểm khách hàng',
      error: error.message,
    });
  } finally {
    connection.release();
  }
});

module.exports = router;
