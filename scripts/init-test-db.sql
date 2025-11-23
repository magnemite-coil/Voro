-- テストユーザーに権限付与
GRANT ALL ON SCHEMA public TO voro_test_user;

-- デフォルト権限設定（将来作成されるテーブルにも適用）
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES TO voro_test_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON SEQUENCES TO voro_test_user;

-- データベース設定
ALTER DATABASE voro_test SET timezone TO 'UTC';
