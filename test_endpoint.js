const http = require('http');
const crypto = require('crypto');

// Generate JWT token matching backend config
function createJwt(userId, email, orgId) {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const payload = Buffer.from(JSON.stringify({
    sub: email,
    userId: userId,
    organization_id: orgId,
    role: 'STUDENT',
    iat: now,
    exp: now + 3600
  })).toString('base64url');

  const secret = 'axisora-forge-academy-secret-key-2024-very-long-secret-key-for-jwt-signing';
  const sig = crypto.createHmac('sha256', secret).update(header + '.' + payload).digest('base64url');
  return header + '.' + payload + '.' + sig;
}

const token = createJwt(2, 'nachireddyvikas2001@gmail.com', 1);

const body = JSON.stringify({
  question: 'What is jdk jre jvm?'
});

const req = http.request({
  hostname: 'localhost',
  port: 8080,
  path: '/api/ai/lesson-chat/131/ask',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ' + token,
    'Content-Length': Buffer.byteLength(body)
  }
}, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log('HTTP STATUS:', res.statusCode);
    try {
      const parsed = JSON.parse(data);
      console.log('RESPONSE:', JSON.stringify(parsed, null, 2));
    } catch (e) {
      console.log('RAW BODY:', data);
    }
  });
});

req.on('error', (e) => console.log('ERROR:', e.message));
req.write(body);
req.end();
