/**
 * StudySnap Mock Backend Server
 * 
 * Standalone Node.js HTTP Server (Zero external dependencies).
 * Implements all 6 core endpoints as specified in Docs (Postman Collection & SRS/SDD Ch. 5):
 * - GET  /v1/health
 * - GET  /v1/terms/current
 * - GET  /v1/timetable?termId=...  (with ETag / 304 Not Modified)
 * - GET  /v1/exams?termId=...      (with ETag / 304 Not Modified)
 * - GET  /v1/campus/buildings
 * - POST /v1/admin/schedule-change (Admin Key protected, triggers FCM simulation)
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { URL } = require('url');

const PORT = process.env.PORT || 3000;
const ADMIN_SECRET_KEY = process.env.ADMIN_SECRET_KEY || 'studysnap_admin_secret_key_2026';

// Helper: Read JSON file safely
function readJsonFile(filename) {
  const filePath = path.join(__dirname, 'data', filename);
  if (!fs.existsSync(filePath)) {
    return null;
  }
  const content = fs.readFileSync(filePath, 'utf-8');
  return JSON.parse(content);
}

// In-memory timetable state
let timetableData = readJsonFile('timetable.json');
let buildingsData = readJsonFile('buildings.json');
let examsData = readJsonFile('exams.json');

// Helper to compute weak ETag
function computeEtag(data) {
  const hash = crypto.createHash('md5').update(JSON.stringify(data)).digest('hex').substring(0, 16);
  return `W/"${hash}"`;
}

// Helper: send JSON response
function sendJson(res, statusCode, data, headers = {}) {
  const body = JSON.stringify(data, null, 2);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Accept, X-Device-Id, If-None-Match, X-Admin-Key',
    ...headers
  });
  res.end(body);
}

const server = http.createServer((req, res) => {
  const startTime = Date.now();
  const parsedUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = parsedUrl.pathname;
  const searchParams = parsedUrl.searchParams;

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Accept, X-Device-Id, If-None-Match, X-Admin-Key'
    });
    return res.end();
  }

  // Response logger on finish
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    console.log(`[${new Date().toISOString()}] ${req.method} ${pathname} -> ${res.statusCode} (${duration}ms)`);
  });

  // 1. GET /v1/health
  if (req.method === 'GET' && pathname === '/v1/health') {
    return sendJson(res, 200, {
      status: 'ok',
      timestamp: new Date().toISOString(),
      version: '1.0.0',
      service: 'StudySnap Mock Backend'
    });
  }

  // 2. GET /v1/terms/current
  if (req.method === 'GET' && pathname === '/v1/terms/current') {
    return sendJson(res, 200, {
      termId: timetableData ? timetableData.termId : '2026-1',
      name: timetableData ? timetableData.termName : 'Học kỳ 1 (2026 - 2027)',
      startDate: '2026-09-01',
      endDate: '2027-01-15',
      isCurrent: true
    });
  }

  // 3. GET /v1/timetable
  if (req.method === 'GET' && pathname === '/v1/timetable') {
    const termId = searchParams.get('termId') || '2026-1';

    if (!timetableData || timetableData.termId !== termId) {
      return sendJson(res, 404, {
        error: 'Not Found',
        message: `Không tìm thấy thời khóa biểu cho học kỳ: ${termId}`
      });
    }

    const currentEtag = computeEtag(timetableData);
    const clientEtag = req.headers['if-none-match'];

    if (clientEtag && (clientEtag === currentEtag || clientEtag === `w/"${currentEtag.replace(/^W\/"|"$/g, '')}"`)) {
      res.writeHead(304, {
        'ETag': currentEtag,
        'Access-Control-Allow-Origin': '*'
      });
      return res.end();
    }

    const responsePayload = {
      ...timetableData,
      etag: currentEtag
    };

    return sendJson(res, 200, responsePayload, { 'ETag': currentEtag });
  }

  // 4. GET /v1/exams
  if (req.method === 'GET' && pathname === '/v1/exams') {
    const termId = searchParams.get('termId') || '2026-1';

    if (!examsData || examsData.termId !== termId) {
      return sendJson(res, 404, {
        error: 'Not Found',
        message: `Không tìm thấy lịch thi cho học kỳ: ${termId}`
      });
    }

    const currentEtag = computeEtag(examsData);
    const clientEtag = req.headers['if-none-match'];

    if (clientEtag && clientEtag === currentEtag) {
      res.writeHead(304, {
        'ETag': currentEtag,
        'Access-Control-Allow-Origin': '*'
      });
      return res.end();
    }

    return sendJson(res, 200, examsData, { 'ETag': currentEtag });
  }

  // 5. GET /v1/campus/buildings
  if (req.method === 'GET' && pathname === '/v1/campus/buildings') {
    if (!buildingsData) {
      return sendJson(res, 500, { error: 'Internal Error', message: 'Dữ liệu tòa nhà không tồn tại' });
    }

    const formattedBuildings = buildingsData.map(b => ({
      id: b.id,
      name: b.name,
      code: b.code,
      latitude: b.latitude,
      longitude: b.longitude,
      radiusMeters: b.radiusMeters || 50
    }));

    return sendJson(res, 200, {
      buildings: formattedBuildings
    });
  }

  // 6. POST /v1/admin/schedule-change
  if (req.method === 'POST' && pathname === '/v1/admin/schedule-change') {
    const adminKey = req.headers['x-admin-key'];
    if (!adminKey || adminKey !== ADMIN_SECRET_KEY) {
      return sendJson(res, 403, {
        error: 'Forbidden',
        message: 'Mã xác thực quản trị viên (X-Admin-Key) không chính xác.'
      });
    }

    let bodyData = '';
    req.on('data', chunk => {
      bodyData += chunk.toString();
    });

    req.on('end', () => {
      try {
        const body = JSON.parse(bodyData || '{}');
        const { slotId, newDayOfWeek, newStartMin, newEndMin, newRoom, reason, notifyFcm } = body;

        if (!slotId) {
          return sendJson(res, 400, {
            error: 'Bad Request',
            message: 'Thiếu slotId ca học cần đổi.'
          });
        }

        // Update in-memory slot
        if (timetableData && timetableData.slots) {
          const slot = timetableData.slots.find(s => s.id === slotId);
          if (slot) {
            if (newDayOfWeek !== undefined) slot.dayOfWeek = newDayOfWeek;
            if (newStartMin !== undefined) slot.startMin = newStartMin;
            if (newEndMin !== undefined) slot.endMin = newEndMin;
            if (newRoom !== undefined) {
              slot.room = newRoom;
              slot.buildingId = newRoom.split('.')[0];
            }
          }
        }

        const jobId = `job-fcm-${Date.now()}`;
        console.log(`[Admin] Đổi lịch cho ca ${slotId}: "${reason}". notifyFcm=${notifyFcm}. Job ID: ${jobId}`);

        return sendJson(res, 202, {
          success: true,
          message: 'Schedule change processed and FCM notification queued.',
          jobId: jobId
        });
      } catch (err) {
        return sendJson(res, 400, {
          error: 'Bad Request',
          message: 'Dữ liệu JSON trong body không hợp lệ: ' + err.message
        });
      }
    });
    return;
  }

  // Serve static Flutter Web build if available (non-API routes)
  const webDir = path.join(__dirname, '..', 'build', 'web');
  if (fs.existsSync(webDir) && req.method === 'GET' && !pathname.startsWith('/v1/')) {
    let filePath = path.join(webDir, pathname === '/' ? 'index.html' : pathname);
    if (!fs.existsSync(filePath)) {
      filePath = path.join(webDir, 'index.html'); // SPA fallback for go_router
    }
    if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
      const ext = path.extname(filePath).toLowerCase();
      const mimeTypes = {
        '.html': 'text/html; charset=utf-8',
        '.js': 'application/javascript',
        '.mjs': 'application/javascript',
        '.css': 'text/css',
        '.json': 'application/json',
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.wasm': 'application/wasm',
        '.ttf': 'font/ttf',
        '.otf': 'font/otf'
      };
      const contentType = mimeTypes[ext] || 'application/octet-stream';
      res.writeHead(200, { 'Content-Type': contentType });
      return fs.createReadStream(filePath).pipe(res);
    }
  }

  // 404 for unknown endpoints
  sendJson(res, 404, {
    error: 'Not Found',
    message: `Đường dẫn ${req.method} ${pathname} không tồn tại trên hệ thống mock backend.`
  });
});

if (require.main === module) {
  server.listen(PORT, () => {
    console.log(`StudySnap Mock Backend Server đang chạy tại http://localhost:${PORT}`);
    console.log(`- Health Check: GET http://localhost:${PORT}/v1/health`);
    console.log(`- Current Term: GET http://localhost:${PORT}/v1/terms/current`);
    console.log(`- Thời khóa biểu: GET http://localhost:${PORT}/v1/timetable?termId=2026-1`);
    console.log(`- Lịch thi: GET http://localhost:${PORT}/v1/exams?termId=2026-1`);
    console.log(`- Tòa nhà cơ sở: GET http://localhost:${PORT}/v1/campus/buildings`);
    console.log(`- Dời lịch (Admin): POST http://localhost:${PORT}/v1/admin/schedule-change`);
  });
}

module.exports = server;
