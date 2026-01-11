// utils/formatDate.ts

/**
 * ISO 8601形式の日時文字列を YYYY/MM/DD 形式に変換
 * ユーザー端末のローカルタイムゾーンで表示する
 *
 * @param isoString - ISO 8601形式の日時文字列（例: "2025-10-25T10:30:00+09:00"）
 * @returns フォーマットされた日付文字列（例: "2025/10/25"）
 *
 * @example
 * // JSTユーザーの場合
 * formatDate("2025-10-25T10:30:00+09:00") // => "2025/10/25"
 *
 * // 日付境界の例（JSTユーザーがUTC深夜の投稿を見る場合）
 * formatDate("2025-10-25T02:00:00Z") // => "2025/10/25" (JST 11:00として表示)
 */
export function formatDate(isoString: string): string {
  const date = new Date(isoString);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}/${month}/${day}`;
}
