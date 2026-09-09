// middleware/errorHandler.js
// JSON 404 + centralized error handler. Keeps stack traces out of
// client responses and formats every error as { error: string }.

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function notFoundHandler(req, res) {
  res.status(404).json({ error: 'Not found' });
}

function jsonErrorHandler(err, req, res, next) {
  if (res.headersSent) return next(err);

  const status = err.status || err.statusCode || 500;

  // body-parser (invalid/malformed JSON) reports with type
  if (err.type === 'entity.too.large') {
    return res.status(413).json({ error: 'Request body too large' });
  }
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'Invalid JSON in request body' });
  }

  const isHttpError = err instanceof HttpError;
  const message =
    status >= 500
      ? 'Internal server error'
      : isHttpError
        ? err.message
        : 'Bad request';

  if (status >= 500) {
    console.error(err);
  }

  res.status(status).json({ error: message });
}

module.exports = { HttpError, notFoundHandler, jsonErrorHandler };