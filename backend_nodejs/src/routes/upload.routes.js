const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');

const router = express.Router();
const uploadDir = path.join(__dirname, '..', '..', 'uploads', 'products');

fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (!file.mimetype.startsWith('image/')) {
      return cb(new Error('Chỉ hỗ trợ upload ảnh'));
    }
    cb(null, true);
  },
});

router.post('/product-image', upload.single('image'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ success: false, message: 'Vui lòng chọn file ảnh' });
  }

  const baseUrl = `${req.protocol}://${req.get('host')}`;
  res.status(201).json({
    success: true,
    message: 'Upload ảnh thành công',
    data: {
      image_url: `${baseUrl}/uploads/products/${req.file.filename}`,
    },
  });
});

module.exports = router;
