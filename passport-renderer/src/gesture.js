/** 距離以 CSS 像素、時間以毫秒計；集中設定方便依裝置微調。 */
export const GESTURE_LIMITS = Object.freeze({
  tapDistance: 10,
  tapDuration: 650,
  swipeDistance: 45,
  swipeDuration: 1400,
  horizontalDominance: 1.3,
});

/**
 * maxDistance 為整段手勢距起點最遠的直線距離，不是累加路徑長度。
 * 已拖離起點再返回的手勢不會被誤認為點擊。
 */
export function classifyGesture({ dx, dy, maxDistance, duration, cancelled = false } = {}) {
  if (cancelled || ![dx, dy, maxDistance, duration].every(Number.isFinite)
    || maxDistance < 0 || duration < 0) {
    return 'cancel';
  }

  const limits = GESTURE_LIMITS;
  if (maxDistance <= limits.tapDistance
    && Math.hypot(dx, dy) <= limits.tapDistance
    && duration <= limits.tapDuration) {
    return 'tap';
  }

  const horizontal = Math.abs(dx);
  if (horizontal >= limits.swipeDistance
    && horizontal > Math.abs(dy) * limits.horizontalDominance
    && maxDistance >= limits.swipeDistance
    && duration <= limits.swipeDuration) {
    return dx < 0 ? 'next' : 'previous';
  }

  return 'cancel';
}
