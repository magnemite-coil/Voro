-- FK制約追加マイグレーション
-- post.user_id → user.id の外部キー制約を追加
--
-- 実行方法:
--   psql -d voro -f scripts/add-fk-constraint.sql
--   psql -d voro_test -f scripts/add-fk-constraint.sql
--
-- 注意:
--   - 既存データに孤立レコード（存在しないuser_idを持つpost）がある場合はエラーになる
--   - 本番環境で実行する前に、孤立レコードがないことを確認すること

-- 既存のFK制約があれば削除（冪等性のため）
ALTER TABLE post
  DROP CONSTRAINT IF EXISTS fk_post_user_id;

-- FK制約を追加
-- ON DELETE RESTRICT: ユーザー削除時に投稿が存在する場合はエラー
-- ON UPDATE CASCADE: ユーザーID変更時に投稿のuser_idも更新（通常は発生しない）
ALTER TABLE post
  ADD CONSTRAINT fk_post_user_id
  FOREIGN KEY (user_id)
  REFERENCES "user"(id)
  ON DELETE RESTRICT
  ON UPDATE CASCADE;

-- 確認用: FK制約が追加されたことを確認
SELECT
  tc.constraint_name,
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'post';
