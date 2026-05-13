const express = require('express');
const pool = require('../config/db');

const router = express.Router();

function toShift(row) {
  if (!row) return null;
  return {
    shift_id: row.shift_id,
    employee_id: row.employee_id,
    shift_date: row.shift_date,
    start_time: row.start_time,
    end_time: row.end_time,
    status: row.status || (row.end_time ? 'closed' : 'active'),
    note: row.note,
  };
}

async function findEmployee(employeeId) {
  const [rows] = await pool.execute(
    `SELECT u.user_id, u.full_name, u.email, r.role_name
     FROM users u
     JOIN roles r ON r.role_id = u.role_id
     WHERE u.user_id = ? AND u.role_id = 2 AND u.status = 'active'
     LIMIT 1`,
    [employeeId]
  );
  return rows[0] || null;
}

async function findActiveShift(connection, employeeId) {
  const hasStatus = await workShiftHasStatus(connection);
  const activeWhere = hasStatus
    ? "end_time IS NULL AND status IN ('active', 'working')"
    : 'end_time IS NULL';
  const [rows] = await connection.execute(
    `SELECT *
     FROM work_shifts
     WHERE employee_id = ?
       AND ${activeWhere}
     ORDER BY shift_date DESC, start_time DESC, shift_id DESC
     LIMIT 1`,
    [employeeId]
  );
  return rows[0] || null;
}

async function workShiftHasStatus(connection) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS count
     FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'work_shifts'
       AND COLUMN_NAME = 'status'`
  );
  return Number(rows[0]?.count || 0) > 0;
}

router.post('/start', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const employeeId = Number(req.body.employee_id);
    if (!employeeId) {
      return res.status(400).json({ success: false, message: 'Vui lòng nhập employee_id' });
    }

    const employee = await findEmployee(employeeId);
    if (!employee) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy nhân viên active' });
    }

    await connection.beginTransaction();
    const hasStatus = await workShiftHasStatus(connection);
    const activeShift = await findActiveShift(connection, employeeId);
    if (activeShift) {
      await connection.commit();
      return res.json({
        success: true,
        message: 'Nhân viên đang có ca active',
        data: toShift(activeShift),
      });
    }

    const [result] = hasStatus
      ? await connection.execute(
          `INSERT INTO work_shifts (employee_id, shift_date, start_time, end_time, status)
           VALUES (?, CURDATE(), CURTIME(), NULL, 'active')`,
          [employeeId]
        )
      : await connection.execute(
          `INSERT INTO work_shifts (employee_id, shift_date, start_time, end_time)
           VALUES (?, CURDATE(), CURTIME(), NULL)`,
          [employeeId]
        );
    const [rows] = await connection.execute('SELECT * FROM work_shifts WHERE shift_id = ?', [
      result.insertId,
    ]);

    await connection.commit();
    res.status(201).json({
      success: true,
      message: 'Đã bắt đầu ca làm',
      data: toShift(rows[0]),
    });
  } catch (error) {
    console.error('work-shifts start failed:', error);
    await connection.rollback();
    res.status(500).json({ success: false, message: 'Lỗi bắt đầu ca làm', error: error.message });
  } finally {
    connection.release();
  }
});

router.post('/end', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const employeeId = Number(req.body.employee_id);
    if (!employeeId) {
      return res.status(400).json({ success: false, message: 'Vui lòng nhập employee_id' });
    }

    await connection.beginTransaction();
    const hasStatus = await workShiftHasStatus(connection);
    const activeShift = await findActiveShift(connection, employeeId);
    if (!activeShift) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Nhân viên chưa có ca active' });
    }

    if (hasStatus) {
      await connection.execute(
        `UPDATE work_shifts
         SET end_time = CURTIME(), status = 'closed'
         WHERE shift_id = ?`,
        [activeShift.shift_id]
      );
    } else {
      await connection.execute(
        `UPDATE work_shifts
         SET end_time = CURTIME()
         WHERE shift_id = ?`,
        [activeShift.shift_id]
      );
    }
    const [rows] = await connection.execute('SELECT * FROM work_shifts WHERE shift_id = ?', [
      activeShift.shift_id,
    ]);

    await connection.commit();
    res.json({
      success: true,
      message: 'Đã kết thúc ca làm',
      data: toShift(rows[0]),
    });
  } catch (error) {
    console.error('work-shifts end failed:', error);
    await connection.rollback();
    res.status(500).json({ success: false, message: 'Lỗi kết thúc ca làm', error: error.message });
  } finally {
    connection.release();
  }
});

module.exports = router;
