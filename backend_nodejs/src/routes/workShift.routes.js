const express = require('express');
const pool = require('../config/db');

const router = express.Router();

function formatDateOnly(value) {
  if (!value) return null;
  if (value instanceof Date) {
    const year = value.getFullYear();
    const month = String(value.getMonth() + 1).padStart(2, '0');
    const day = String(value.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
  return String(value).slice(0, 10);
}

function formatTimeOnly(value) {
  if (!value) return null;
  if (value instanceof Date) {
    const hour = String(value.getHours()).padStart(2, '0');
    const minute = String(value.getMinutes()).padStart(2, '0');
    const second = String(value.getSeconds()).padStart(2, '0');
    return `${hour}:${minute}:${second}`;
  }
  return String(value).slice(0, 8);
}

function toShift(row) {
  if (!row) return null;
  return {
    shift_id: row.shift_id,
    employee_id: row.employee_id,
    shift_date: formatDateOnly(row.shift_date),
    start_time: formatTimeOnly(row.start_time),
    end_time: formatTimeOnly(row.end_time),
    status: row.status || (row.end_time ? 'closed' : 'active'),
    note: row.note,
  };
}

async function findEmployee(employeeId) {
  const [rows] = await pool.execute(
    `SELECT u.user_id, u.full_name, u.email, r.role_name
     FROM users u
     JOIN roles r ON r.role_id = u.role_id
     WHERE u.user_id = ?
       AND r.role_name = 'employee'
       AND u.status = 'active'
     LIMIT 1`,
    [employeeId]
  );
  return rows[0] || null;
}

async function findActiveShift(connection, employeeId) {
  const hasStatus = await workShiftHasStatus(connection);
  const activeWhere = hasStatus
    ? "end_time IS NULL AND status IN ('active', 'working', 'open')"
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

router.get('/employee/:employeeId', async (req, res) => {
  try {
    const employeeId = Number(req.params.employeeId);
    if (!employeeId) {
      return res.status(400).json({ success: false, message: 'employeeId không hợp lệ' });
    }

    const now = new Date();
    const year = Number(req.query.year) || now.getFullYear();
    const month = Number(req.query.month) || now.getMonth() + 1;

    const [rows] = await pool.execute(
      `SELECT *
       FROM work_shifts
       WHERE employee_id = ?
         AND YEAR(shift_date) = ?
         AND MONTH(shift_date) = ?
       ORDER BY shift_date DESC, start_time DESC, shift_id DESC`,
      [employeeId, year, month]
    );

    res.json({
      success: true,
      data: rows.map(toShift),
      meta: { year, month, total: rows.length },
    });
  } catch (error) {
    console.error('work-shifts list failed:', error);
    res.status(500).json({
      success: false,
      message: 'Lỗi lấy lịch ca làm',
      error: error.message,
    });
  }
});

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
           VALUES (?, CURDATE(), CURTIME(), NULL, 'working')`,
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
         SET end_time = CURTIME(), status = 'completed'
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
