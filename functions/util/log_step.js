/**
 * Step logging for Cloud Functions (console.log + Firebase logger).
 * @param {string} step
 * @param {Record<string, unknown>} [data]
 */
function logStep(step, data) {
  const line = data ? `${step} ${JSON.stringify(data)}` : step;
  console.log(line);
  try {
    const { logger } = require('firebase-functions');
    if (data) {
      logger.info(step, data);
    } else {
      logger.info(step);
    }
  } catch (_) {
    /* firebase-functions not loaded in scripts */
  }
}

/**
 * @param {string} step
 * @param {unknown} error
 */
function logError(step, error) {
  const err = error instanceof Error ? error : new Error(String(error));
  console.error(step, err.message);
  console.error(err.stack);
  try {
    const { logger } = require('firebase-functions');
    logger.error(step, { message: err.message, stack: err.stack });
  } catch (_) {
    /* ignore */
  }
}

module.exports = { logStep, logError };
