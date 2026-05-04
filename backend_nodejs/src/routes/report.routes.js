const express = require('express');
const pool = require('../config/db');

const router = express.Router();

async function requireAdmin(req, res, next) {
  try {
    const userId = Number(req.get('x-user-id'));
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Thiếu thông tin admin',
      });
    }

    const [users] = await pool.execute(
      `SELECT u.user_id
       FROM users u
       JOIN roles r ON r.role_id = u.role_id
       WHERE u.user_id = ? AND r.role_name = 'admin' AND u.status = 'active'`,
      [userId]
    );

    if (users.length === 0) {
      return res.status(403).json({
        success: false,
        message: 'Chỉ admin được xem báo cáo',
      });
    }
    next();
  } catch (error) {
    return res.status(403).json({
      success: false,
      message: 'Không kiểm tra được quyền admin',
      error: error.message,
    });
  }
}

const paidOrderCondition =
  "(o.payment_status IN ('paid', 'success') OR o.status IN ('completed', 'hoàn thành'))";

const latestImportPriceSql = `
  SELECT
    ii.barcode,
    COALESCE(
      (
        SELECT il.import_price
        FROM inventory_logs il
        WHERE il.inventory_item_id = ii.inventory_item_id
          AND il.action = 'import'
          AND il.import_price IS NOT NULL
        ORDER BY il.created_at DESC, il.log_id DESC
        LIMIT 1
      ),
      ii.import_price
    ) AS import_price
  FROM inventory_items ii
`;

router.use(requireAdmin);

router.get('/revenue', async (req, res) => {
  try {
    const [summaryRows] = await pool.execute(
      `SELECT
         COALESCE(SUM(oi.subtotal), 0) AS total_revenue,
         COUNT(DISTINCT o.order_id) AS total_orders,
         COALESCE(SUM(oi.quantity), 0) AS total_products_sold,
         COALESCE(SUM(CASE WHEN cost.import_price IS NULL THEN 1 ELSE 0 END), 0) AS missing_cost_lines,
         COALESCE(SUM(oi.subtotal - (oi.quantity * cost.import_price)), 0) AS total_profit
       FROM orders o
       JOIN order_items oi ON oi.order_id = o.order_id
       JOIN products p ON p.product_id = oi.product_id
       LEFT JOIN (${latestImportPriceSql}) cost ON cost.barcode = p.barcode
       WHERE ${paidOrderCondition}`
    );

    const [timeRows] = await pool.execute(
      `SELECT
         DATE(o.created_at) AS period,
         COALESCE(SUM(o.final_amount), 0) AS revenue,
         COUNT(DISTINCT o.order_id) AS orders_count
       FROM orders o
       WHERE ${paidOrderCondition}
       GROUP BY DATE(o.created_at)
       ORDER BY period ASC`
    );

    const summary = summaryRows[0] || {};
    const totalProductsSold = Number(summary.total_products_sold || 0);
    const missingCostLines = Number(summary.missing_cost_lines || 0);
    const totalProfit =
      totalProductsSold > 0 && missingCostLines > 0
        ? null
        : Number(summary.total_profit || 0);

    res.json({
      success: true,
      data: {
        total_revenue: Number(summary.total_revenue || 0),
        total_profit: totalProfit,
        profit_note:
          totalProfit == null
            ? 'Chưa đủ dữ liệu tính lợi nhuận: một số sản phẩm đã bán chưa có import_price.'
            : null,
        total_orders: Number(summary.total_orders || 0),
        total_products_sold: totalProductsSold,
        revenue_by_time: timeRows.map((row) => ({
          period: row.period,
          revenue: Number(row.revenue || 0),
          orders_count: Number(row.orders_count || 0),
        })),
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Lỗi lấy báo cáo doanh thu',
      error: error.message,
    });
  }
});

router.get('/product-performance', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT
         p.product_id,
         p.product_name,
         COALESCE(SUM(oi.quantity), 0) AS total_quantity_sold,
         COALESCE(SUM(oi.subtotal), 0) AS total_revenue,
         CASE
           WHEN SUM(CASE WHEN cost.import_price IS NULL THEN 1 ELSE 0 END) > 0
             THEN NULL
           ELSE COALESCE(SUM(oi.subtotal - (oi.quantity * cost.import_price)), 0)
         END AS total_profit,
         p.stock AS current_stock,
         cost.import_price
       FROM products p
       JOIN order_items oi ON oi.product_id = p.product_id
       JOIN orders o ON o.order_id = oi.order_id
       LEFT JOIN (${latestImportPriceSql}) cost ON cost.barcode = p.barcode
       WHERE p.status <> 'deleted'
         AND ${paidOrderCondition}
       GROUP BY p.product_id, p.product_name, p.stock, cost.import_price
       ORDER BY total_quantity_sold DESC, total_revenue DESC, p.product_name ASC`
    );

    res.json({
      success: true,
      data: rows.map((row) => ({
        product_id: row.product_id,
        product_name: row.product_name,
        total_quantity_sold: Number(row.total_quantity_sold || 0),
        total_revenue: Number(row.total_revenue || 0),
        total_profit:
          row.total_profit == null ? null : Number(row.total_profit || 0),
        current_stock: Number(row.current_stock || 0),
        import_price:
          row.import_price == null ? null : Number(row.import_price || 0),
      })),
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Lỗi lấy báo cáo hiệu suất sản phẩm',
      error: error.message,
    });
  }
});

module.exports = router;
