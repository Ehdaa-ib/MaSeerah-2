/**
 * Wraps callable handlers — logs errors and returns client-visible HttpsError messages.
 */
const { HttpsError } = require('firebase-functions/v2/https');
const { logStep, logError } = require('./log_step');

/**
 * Never surface bare "internal" to the client; attach message in details.
 * @param {string} code
 * @param {string} message
 */
function throwCallableError(code, message) {
  const msg =
    message && String(message).trim()
      ? String(message).trim()
      : 'Unknown email error';
  const clientCode = code === 'internal' ? 'failed-precondition' : code;
  throw new HttpsError(clientCode, msg, { message: msg });
}

/**
 * @param {string} label
 * @param {(request: import('firebase-functions/v2/https').CallableRequest) => Promise<unknown>} handler
 */
function wrapCallable(label, handler) {
  return async (request) => {
    logStep(`${label}: Function started`);
    try {
      const result = await handler(request);
      logStep(`${label}: completed OK`);
      return result;
    } catch (e) {
      if (e instanceof HttpsError) {
        logError(`${label}: HttpsError`, e);
        const msg = e.message || 'Unknown email error';
        throwCallableError(e.code, msg);
      }
      logError(`${label}: EMAIL SEND ERROR`, e);
      const msg =
        e && e.message && String(e.message).trim()
          ? String(e.message).trim()
          : 'Unknown email error';
      throwCallableError('internal', msg);
    }
  };
}

module.exports = { wrapCallable, throwCallableError };
