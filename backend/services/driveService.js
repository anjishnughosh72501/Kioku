// services/driveService.js
// Thin wrapper around the Google Drive API. Your personal Google account
// authorizes once (see scripts/getRefreshToken.js) and the server then
// acts on your behalf for every friend's upload - friends never see Google.

const { google } = require('googleapis');
const { Readable } = require('stream');
require('dotenv').config();

const oauth2Client = new google.auth.OAuth2(
  process.env.GOOGLE_CLIENT_ID,
  process.env.GOOGLE_CLIENT_SECRET,
  process.env.GOOGLE_REDIRECT_URI
);

oauth2Client.setCredentials({
  refresh_token: process.env.GOOGLE_REFRESH_TOKEN,
});

const drive = google.drive({ version: 'v3', auth: oauth2Client });

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(
      `Missing required env var ${name}. Copy backend/.env.example to backend/.env and fill it in.`
    );
  }
  return value;
}

/**
 * Creates (or reuses) a subfolder for a group inside the Retro root folder.
 */
async function ensureGroupFolder(groupName) {
  const rootId = requireEnv('GOOGLE_DRIVE_ROOT_FOLDER_ID');
  requireEnv('GOOGLE_REFRESH_TOKEN');

  // Escape single quotes so group names can't break/alter the Drive query
  const safeName = groupName.replace(/'/g, "\\'");

  const existing = await drive.files.list({
    q: `'${rootId}' in parents and name='${safeName}' and mimeType='application/vnd.google-apps.folder' and trashed=false`,
    fields: 'files(id, name)',
  });

  if (existing.data.files.length > 0) {
    return existing.data.files[0].id;
  }

  const folder = await drive.files.create({
    requestBody: {
      name: groupName,
      mimeType: 'application/vnd.google-apps.folder',
      parents: [rootId],
    },
    fields: 'id',
  });

  return folder.data.id;
}

/**
 * Uploads a file buffer to a given Drive folder and returns the file ID
 * plus a direct-viewable URL.
 */
async function uploadFile({ buffer, filename, mimeType, folderId }) {
  requireEnv('GOOGLE_REFRESH_TOKEN');

  const res = await drive.files.create({
    requestBody: {
      name: filename,
      parents: [folderId],
    },
    media: {
      mimeType,
      body: Readable.from(buffer),
    },
    fields: 'id',
  });

  const fileId = res.data.id;

  return {
    fileId,
    // Direct view & thumbnail URLs (access governed by folder permissions)
    viewUrl: `https://drive.google.com/uc?export=view&id=${fileId}`,
    thumbnailUrl: `https://drive.google.com/thumbnail?id=${fileId}&sz=w500`,
  };
}

module.exports = { ensureGroupFolder, uploadFile };
