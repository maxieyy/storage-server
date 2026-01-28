const express = require('express');
const multer = require('multer');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { promisify } = require('util');

const mkdir = promisify(fs.mkdir);
const stat = promisify(fs.stat);
const readdir = promisify(fs.readdir);

const app = express();
const PORT = process.env.PORT || 3001;
const STORAGE_PATH = process.env.STORAGE_PATH || '/var/media-storage';

// Middleware
app.use(cors());
app.use(express.json());

// Configure multer for file storage
const storage = multer.diskStorage({
    destination: async (req, file, cb) => {
        const uploadDir = path.join(STORAGE_PATH, 'uploads');

        try {
            await mkdir(uploadDir, { recursive: true });
            cb(null, uploadDir);
        } catch (error) {
            cb(error);
        }
    },
    filename: (req, file, cb) => {
        cb(null, file.originalname);
    },
});

const upload = multer({ storage });

// Health check endpoint
app.get('/health', async (req, res) => {
    try {
        // Get disk space (simplified version)
        const storageStats = await getStorageStats();

        res.json({
            status: 'healthy',
            timestamp: new Date().toISOString(),
            storage: storageStats,
        });
    } catch (error) {
        res.status(503).json({
            status: 'unhealthy',
            error: error.message,
        });
    }
});

// Upload file endpoint
app.post('/upload', upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({
                success: false,
                error: 'No file uploaded',
            });
        }

        res.json({
            success: true,
            file: {
                filename: req.file.filename,
                path: req.file.path,
                size: req.file.size,
            },
        });
    } catch (error) {
        console.error('Upload error:', error);
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

// Get file endpoint
app.get('/files/:id', async (req, res) => {
    try {
        const fileId = req.params.id;
        const filePath = path.join(STORAGE_PATH, 'uploads', fileId);

        // Check if file exists
        await stat(filePath);

        res.sendFile(filePath);
    } catch (error) {
        res.status(404).json({
            success: false,
            error: 'File not found',
        });
    }
});

// Delete file endpoint
app.delete('/files/:filename', async (req, res) => {
    try {
        const filename = req.params.filename;
        const filePath = path.join(STORAGE_PATH, 'uploads', filename);

        await promisify(fs.unlink)(filePath);

        res.json({
            success: true,
            message: 'File deleted',
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

// List files endpoint
app.get('/files', async (req, res) => {
    try {
        const uploadDir = path.join(STORAGE_PATH, 'uploads');
        const files = await readdir(uploadDir);

        const fileStats = await Promise.all(
            files.map(async (filename) => {
                const filePath = path.join(uploadDir, filename);
                const stats = await stat(filePath);
                return {
                    filename,
                    size: stats.size,
                    created: stats.birthtime,
                    modified: stats.mtime,
                };
            })
        );

        res.json({
            success: true,
            files: fileStats,
        });
    } catch (error) {
        res.json({
            success: true,
            files: [],
        });
    }
});

// Helper function to get storage stats
async function getStorageStats() {
    try {
        const uploadDir = path.join(STORAGE_PATH, 'uploads');

        // Ensure directory exists
        await mkdir(uploadDir, { recursive: true });

        const files = await readdir(uploadDir);

        let totalSize = 0;
        for (const file of files) {
            const filePath = path.join(uploadDir, file);
            const stats = await stat(filePath);
            if (stats.isFile()) {
                totalSize += stats.size;
            }
        }

        return {
            used: totalSize,
            total: 42949672960, // 40GB - this should be dynamically detected
            available: 42949672960 - totalSize,
        };
    } catch (error) {
        return {
            used: 0,
            total: 42949672960,
            available: 42949672960,
        };
    }
}

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`📦 Storage Node running on port ${PORT}`);
    console.log(`💾 Storage path: ${STORAGE_PATH}`);
});

module.exports = app;
