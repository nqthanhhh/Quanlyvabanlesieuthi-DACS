const express = require('express');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

const pool = require('./config/db');

const app = express();

app.use(cors());
app.use(express.json());

const authRoutes = require('./routes/auth.routes');
const userRoutes = require('./routes/user.routes');
const categoryRoutes = require('./routes/category.routes');
const productRoutes = require('./routes/product.routes');
const cartRoutes = require('./routes/cart.routes');
const orderRoutes = require('./routes/order.routes');
const inventoryRoutes = require('./routes/inventory.routes');
const uploadRoutes = require('./routes/upload.routes');

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/products', productRoutes);
app.use('/api/carts', cartRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/inventory', inventoryRoutes);
app.use('/api/uploads', uploadRoutes);
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Mini Market API is running',
  });
});

app.get('/api/test-db', async (req, res) => {
  try {
    const [rows] = await pool.execute('SELECT * FROM roles');

    res.json({
      success: true,
      message: 'Kết nối database thành công',
      data: rows,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Không kết nối được database',
      error: error.message,
    });
  }
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server đang chạy tại http://localhost:${PORT}`);
});
