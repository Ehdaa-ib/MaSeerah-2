/**
 * Wraps callable handlers so unexpected errors become HttpsError with a client-visible message.
 */
const { HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');

/**
 * @param {string} label
 * @param {(request: import('firebase-functions/v2/https').CallableRequest) => Promise<unknown>} handler
 */
function wrapCallable(label, handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (e) {
      if (e instanceof HttpsError) {
        logger.warn(`[${label}] HttpsError`, {
          code: e.code,
          message: e.message,
          details: e.details,
        });
        if (!e.details && e.message) {
          throw new HttpsError(e.code, e.message, { message: e.message });
        }
        throw e;
      }
      logger.error(`[${label}] unhandled exception`, {
        message: e && e.message,
        stack: e && e.stack,
        name: e && e.name,
      });
      const detail =
        e && e.message && String(e.message).trim()
          ? String(e.message).trim()
          : 'Unexpected server error';
      throw new HttpsError(
        'failed-precondition',
        `${label} failed: ${detail}`,
      );
    }
  };
}

module.exports = { wrapCallable };
