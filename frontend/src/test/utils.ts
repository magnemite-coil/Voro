/**
 * テスト用共有ユーティリティ
 */

/**
 * 認証済みユーザーをセットアップする
 * localStorageに認証情報を保存する
 *
 * @param userId - ユーザーID（デフォルト: 1）
 * @param username - ユーザー名（デフォルト: 'testuser'）
 */
export function setupAuthenticatedUser(
  userId: number = 1,
  username: string = 'testuser'
): void {
  localStorage.setItem(
    'voro_auth',
    JSON.stringify({ userId, username })
  );
}
