// scripts/getRefreshToken.js
// Run this ONCE (node scripts/getRefreshToken.js) to authorize your own
// Google account and get a refresh token. Paste the result into .env as
// GOOGLE_REFRESH_TOKEN. You will not need to run this again unless you
// revoke access.

require('dotenv').config();
const { google } = require('googleapis');
const readline = require('readline');

const oauth2Client = new google.auth.OAuth2(
  process.env.GOOGLE_CLIENT_ID,
  process.env.GOOGLE_CLIENT_SECRET,
  process.env.GOOGLE_REDIRECT_URI
);

const authUrl = oauth2Client.generateAuthUrl({
  access_type: 'offline',
  prompt: 'consent',
  scope: ['https://www.googleapis.com/auth/drive.file'],
});

console.log('\n1. Open this URL in your browser and authorize:\n');
console.log(authUrl);
console.log('\n2. After authorizing, copy the "code" value from the redirected URL.\n');

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
rl.question('Paste the code here: ', async (code) => {
  const { tokens } = await oauth2Client.getToken(code);
  console.log('\nYour refresh token (put this in .env as GOOGLE_REFRESH_TOKEN):\n');
  console.log(tokens.refresh_token);
  rl.close();
});
