# Voroテストガイド

このディレクトリには、Voroプロジェクトのテスト実行とテスト開発に関するドキュメントが含まれています。

## 📚 ドキュメント一覧

- **[backend-guide.md](./backend-guide.md)** - バックエンドテストの詳細ガイド
  - テストの書き方
  - HTTP統合テスト
  - フィクスチャの使い方
  - ベストプラクティス

- **[troubleshooting.md](./troubleshooting.md)** - トラブルシューティングガイド
  - よくある問題と解決方法
  - デバッグ手法
  - パフォーマンス問題

## 🚀 クイックスタート

### テスト実行方法

```bash
# Docker環境で全テストを実行
make test

# テストコンテナのシェルに入る
make shell-test

# テストログを表示
make logs
```

### テスト環境

Voroのテストは、本番環境を汚染しないように**Docker環境専用**で実行されます。

**主要コンポーネント:**
- **PostgreSQL 15**: テスト用データベース (`voro_test`)
- **Redis 7**: テスト用セッションストア (DB 1)
- **SBCL 2.2.4**: Common Lisp処理系
- **Rove**: テストフレームワーク

## 🧪 テストスイート概要

Voroには以下のテストスイートがあります：

### 1. Utilテスト (`test/util-test.lisp`)
- バリデーション関数のテスト
- パスワードハッシュ化のテスト
- 全32テストケース

### 2. Modelテスト (`test/model-test.lisp`)
- データベースモデルのCRUD操作
- Mito ORMの動作確認
- 全7テストケース

### 3. Serviceテスト (`test/service-test.lisp`)
- ビジネスロジックのテスト
- ユーザー登録・認証フロー
- 全13テストケース

### 4. Handlerテスト (`test/handler-test.lisp`, `test/handler/auth-test.lisp`)
- HTTP APIエンドポイントのテスト
- リクエスト/レスポンスの検証
- Cookie/セッション管理
- 全10テストケース

## 🛡️ 8層防御システム

Voroのテスト基盤は、本番データベースを保護するための**8層防御**を実装しています：

### 環境変数による防御（層1-3）
1. `TEST_MODE=true` 必須チェック
2. `APP_ENV=test` 必須チェック
3. `TEST_DB_NAME` 必須チェック

### データベース名による防御（層4-5）
4. DB名に `_test` サフィックス必須
5. 本番DB名（`voro_production`等）の明示的拒否

### テーブル存在確認（層6）
6. テスト実行前のテーブル存在確認

### トランザクション防御（層7-8）
7. `with-test-db` マクロによる自動ロールバック
8. 強制ロールバック条件（`test-rollback-condition`）

詳細は [backend-guide.md](./backend-guide.md) を参照してください。

## 📊 カバレッジ目標

| レイヤー | 目標カバレッジ | 現状 |
|---------|--------------|------|
| Util層 | 90%+ | ✅ 高カバレッジ |
| Model層 | 80%+ | ✅ 高カバレッジ |
| Service層 | 80%+ | ✅ 高カバレッジ |
| Handler層 | 70%+ | ✅ Phase3完了 |

## 🔧 開発ワークフロー

### 新しいテストを書く場合

1. `.claude/rules/testing.md` でテスト戦略を確認
2. `backend-guide.md` で実装パターンを参照
3. 適切なテストスイートにテストを追加
4. `make test` でテスト実行
5. 全テスト成功を確認してコミット

### テストが失敗した場合

1. `make logs` でログを確認
2. `troubleshooting.md` でよくある問題を確認
3. 必要に応じて `make shell-test` でデバッグ

## 📖 関連ドキュメント

- **設計書**: `docs/design/test-infrastructure-docker.md`
- **テスト戦略**: `.claude/rules/testing.md`
- **実装ルール**: `.claude/rules/implementation.md`

## ⚠️ 重要な注意事項

1. **本番環境でのテスト実行禁止**
   - テストは必ずDocker環境で実行してください
   - `TEST_MODE=true` が設定されていることを確認してください

2. **mainブランチでの作業禁止**
   - テストコードの変更も作業用ブランチで行ってください

3. **テストの独立性**
   - 各テストは独立して実行可能である必要があります
   - テスト間で状態を共有しないでください
   - `with-test-db` マクロを使用してトランザクション分離を保証してください

## 🤝 貢献ガイドライン

テストコードを追加・修正する際は、以下を遵守してください：

1. **テストの命名規則**: `test-<function-name>` または `<feature>-test`
2. **説明的なテストケース名**: 何をテストするか明確に記述
3. **Arrange-Act-Assert**: テストの構造を明確に
4. **エッジケースのテスト**: 正常系だけでなく異常系もカバー

詳細は [backend-guide.md](./backend-guide.md) の「テストの書き方」セクションを参照してください。
