const http = require('http');
const server = require('./server');

const TEST_PORT = 3123;

function request(options, postData = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: data ? JSON.parse(data) : null
        });
      });
    });
    req.on('error', reject);
    if (postData) {
      req.write(typeof postData === 'string' ? postData : JSON.stringify(postData));
    }
    req.end();
  });
}

async function runTests() {
  server.listen(TEST_PORT, async () => {
    console.log(`[TEST] Test server started on port ${TEST_PORT}`);
    let passCount = 0;
    let failCount = 0;

    function assert(name, condition) {
      if (condition) {
        console.log(`  PASSED: ${name}`);
        passCount++;
      } else {
        console.error(`  FAILED: ${name}`);
        failCount++;
      }
    }

    try {
      // 1. Health check
      const healthRes = await request({
        hostname: 'localhost',
        port: TEST_PORT,
        path: '/v1/health',
        method: 'GET'
      });
      assert('GET /v1/health status 200', healthRes.statusCode === 200);
      assert('GET /v1/health status === "ok"', healthRes.body.status === 'ok');

      // 2. Terms current
      const termsRes = await request({
        hostname: 'localhost',
        port: TEST_PORT,
        path: '/v1/terms/current',
        method: 'GET'
      });
      assert('GET /v1/terms/current status 200', termsRes.statusCode === 200);
      assert('GET /v1/terms/current termId === "2026-1"', termsRes.body.termId === '2026-1');

      // 3. Timetable
      const ttRes = await request({
        hostname: 'localhost',
        port: TEST_PORT,
        path: '/v1/timetable?termId=2026-1',
        method: 'GET'
      });
      assert('GET /v1/timetable status 200', ttRes.statusCode === 200);
      assert('GET /v1/timetable has ETag header', !!ttRes.headers['etag']);
      assert('GET /v1/timetable has subjects & slots', Array.isArray(ttRes.body.subjects) && Array.isArray(ttRes.body.slots));

      // 4. Timetable ETag 304 Not Modified
      const etag = ttRes.headers['etag'];
      const tt304Res = await request({
        hostname: 'localhost',
        port: TEST_PORT,
        path: '/v1/timetable?termId=2026-1',
        method: 'GET',
        headers: { 'if-none-match': etag }
      });
      assert('GET /v1/timetable with If-None-Match returns 304', tt304Res.statusCode === 304);

      // 5. Exams
      const examsRes = await request({
        hostname: 'localhost',
        port: TEST_PORT,
        path: '/v1/exams?termId=2026-1',
        method: 'GET'
      });
      assert('GET /v1/exams status 200', examsRes.statusCode === 200);
      assert('GET /v1/exams returns exams array', Array.isArray(examsRes.body.exams) && examsRes.body.exams.length > 0);

      // 6. Campus buildings
      const bldRes = await request({
        hostname: 'localhost',
        port: TEST_PORT,
        path: '/v1/campus/buildings',
        method: 'GET'
      });
      assert('GET /v1/campus/buildings status 200', bldRes.statusCode === 200);
      assert('GET /v1/campus/buildings returns buildings list', Array.isArray(bldRes.body.buildings) && bldRes.body.buildings.length >= 10);

      // 7. Admin Schedule Change without key -> 403
      const adminNoKey = await request({
        hostname: 'localhost',
        port: TEST_PORT,
        path: '/v1/admin/schedule-change',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      }, { slotId: 'slot_mon_1', newRoom: 'H2.501' });
      assert('POST /v1/admin/schedule-change without key returns 403', adminNoKey.statusCode === 403);

      // 8. Admin Schedule Change with valid key -> 202
      const adminValid = await request({
        hostname: 'localhost',
        port: TEST_PORT,
        path: '/v1/admin/schedule-change',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Admin-Key': 'studysnap_admin_secret_key_2026'
        }
      }, {
        slotId: 'slot_mon_1',
        newRoom: 'H2.501',
        reason: 'Đổi phòng thí nghiệm',
        notifyFcm: true
      });
      assert('POST /v1/admin/schedule-change with key returns 202', adminValid.statusCode === 202);
      assert('POST /v1/admin/schedule-change has success: true', adminValid.body.success === true);

      // 9. 404 Route
      const notFoundRes = await request({
        hostname: 'localhost',
        port: TEST_PORT,
        path: '/v1/invalid-route',
        method: 'GET'
      });
      assert('GET /v1/invalid-route returns 404', notFoundRes.statusCode === 404);

    } catch (err) {
      console.error('[TEST ERROR]', err);
      failCount++;
    } finally {
      server.close(() => {
        console.log(`\n================================`);
        console.log(`Backend Test Summary: ${passCount} PASSED, ${failCount} FAILED`);
        console.log(`================================`);
        process.exit(failCount === 0 ? 0 : 1);
      });
    }
  });
}

runTests();
