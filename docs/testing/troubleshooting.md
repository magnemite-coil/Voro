# テストトラブルシューティングガイド

Voroプロジェクトのテスト実行中に発生する問題と解決方法をまとめたガイドです。

## 📋 目次

1. [環境関連の問題](#環境関連の問題)
2. [データベース関連の問題](#データベース関連の問題)
3. [Redis関連の問題](#redis関連の問題)
4. [HTTP統合テストの問題](#http統合テストの問題)
5. [パフォーマンスの問題](#パフォーマンスの問題)
6. [デバッグ手法](#デバッグ手法)

---

## 環境関連の問題

### 問題: Docker コンテナが起動しない

**症状:**
```bash
$ make test
ERROR: Service 'test-db' failed to start
```

**原因:**
- Dockerデーモンが起動していない
- ポート競合（5432, 6379が既に使用されている）
- Dockerリソース不足

**解決方法:**

```bash
# 1. Dockerデーモンの確認
docker ps

# 2. ポート競合の確認
lsof -i :5432
lsof -i :6379

# 3. 既存コンテナのクリーンアップ
make clean
docker-compose -f docker-compose.test.yml down -v

# 4. Dockerリソースの確認・増加
# Docker Desktop > Preferences > Resources
# メモリを4GB以上に設定
```

### 問題: Quicklisp のダウンロードが遅い

**症状:**
```
Downloading dependencies... (takes 5+ minutes)
```

**原因:**
- Quicklisp ミラーサーバーが遅い
- キャッシュが無効化されている

**解決方法:**

```bash
# 1. キャッシュボリュームの確認
docker volume ls | grep sbcl-cache

# 2. キャッシュボリュームの再作成
docker volume rm voro_sbcl-cache
docker volume create voro_sbcl-cache

# 3. Dockerfile.test の確認
# Quicklisp がキャッシュされていることを確認
```

### 問題: テスト環境変数が設定されていない

**症状:**
```
ERROR: TEST_MODE environment variable is not set
```

**原因:**
- `docker-compose.test.yml` の環境変数設定が欠落

**解決方法:**

```bash
# docker-compose.test.yml の environment セクションを確認
cat docker-compose.test.yml | grep -A 20 environment
```

必要な環境変数:
```yaml
environment:
  APP_ENV: test
  TEST_MODE: "true"
  TEST_DB_NAME: voro_test
  TEST_DB_USER: voro_test_user
  TEST_DB_PASSWORD: voro_test_password
  DB_HOST: test-db
  DB_PORT: 5432
  REDIS_HOST: test-redis
  REDIS_PORT: 6379
  TEST_REDIS_DB: 1
```

---

## データベース関連の問題

### 問題: 本番DB保護エラー

**症状:**
```
ERROR: Test database verification failed: DB name does not contain '_test'
```

**原因:**
- 8層防御による本番DB保護が働いている
- 環境変数の設定ミス

**解決方法:**

```bash
# 1. 環境変数の確認
docker-compose -f docker-compose.test.yml exec test-runner env | grep DB

# 2. 正しい値を確認
# TEST_DB_NAME=voro_test (必ず _test サフィックス)
# DB_HOST=test-db
# APP_ENV=test
# TEST_MODE=true

# 3. docker-compose.test.yml を修正して再起動
make clean
make test
```

### 問題: データベース接続エラー

**症状:**
```
ERROR: Could not connect to database
DBI:CONNECT-ERROR: connection to server at "test-db", port 5432 failed
```

**原因:**
- PostgreSQL コンテナが起動していない
- ヘルスチェックが失敗している
- ネットワーク設定の問題

**解決方法:**

```bash
# 1. PostgreSQL コンテナの状態確認
docker-compose -f docker-compose.test.yml ps

# 2. PostgreSQL ログの確認
docker-compose -f docker-compose.test.yml logs test-db

# 3. ヘルスチェックの確認
docker-compose -f docker-compose.test.yml exec test-db \
  pg_isready -U voro_test_user -d voro_test

# 4. コンテナの再起動
docker-compose -f docker-compose.test.yml restart test-db

# 5. 完全なクリーンアップと再起動
make clean
make test
```

### 問題: テーブルが作成されない

**症状:**
```
ERROR: Table "user" does not exist
```

**原因:**
- マイグレーションが実行されていない
- `setup-test-environment` が呼ばれていない

**解決方法:**

```lisp
;; test/setup.lisp の確認
(defun setup-test-environment ()
  "テスト環境のセットアップ"
  (connect-db)
  (connect-redis)
  (verify-test-database)
  ;; テーブル作成
  (mito:ensure-table-exists 'voro.model.user:user))

;; テストファイルの確認
(setup
  (setup-test-environment))
```

### 問題: テストデータがロールバックされない

**症状:**
```
ERROR: Unique constraint violation (username already exists)
```

**原因:**
- `with-test-db` マクロを使用していない
- トランザクションが正しく動作していない

**解決方法:**

```lisp
;; ❌ 悪い例
(deftest bad-test
  (let ((user (create-user ...)))
    ;; データがDBに残る
    ))

;; ✅ 良い例
(deftest good-test
  (with-test-db
    (let ((user (create-user ...)))
      ;; テスト終了後は自動ロールバック
      )))
```

---

## Redis関連の問題

### 問題: Redis 接続エラー

**症状:**
```
ERROR: Could not connect to Redis
REDIS:CONNECTION-ERROR: Failed to connect to test-redis:6379
```

**原因:**
- Redis コンテナが起動していない
- ポート競合

**解決方法:**

```bash
# 1. Redis コンテナの状態確認
docker-compose -f docker-compose.test.yml ps test-redis

# 2. Redis ログの確認
docker-compose -f docker-compose.test.yml logs test-redis

# 3. Redis接続テスト
docker-compose -f docker-compose.test.yml exec test-redis redis-cli ping
# 期待される出力: PONG

# 4. コンテナの再起動
docker-compose -f docker-compose.test.yml restart test-redis
```

### 問題: Redis DB番号の設定ミス

**症状:**
```
WARNING: Using Redis DB 0 (production)
```

**原因:**
- `TEST_REDIS_DB` 環境変数が正しく設定されていない

**解決方法:**

```bash
# 1. 環境変数の確認
docker-compose -f docker-compose.test.yml exec test-runner env | grep REDIS

# 2. 正しい値
# TEST_REDIS_DB=1 (必ずDB 1を使用)
# REDIS_HOST=test-redis
# REDIS_PORT=6379

# 3. docker-compose.test.yml を確認・修正
```

---

## HTTP統合テストの問題

### 問題: HTTPサーバーが起動しない

**症状:**
```
ERROR: Failed to start HTTP server on port 15555
```

**原因:**
- ポート競合
- Woo サーバーの初期化失敗

**解決方法:**

```lisp
;; 1. ポート番号の変更
(defparameter *test-http-port* 15556) ;; 別のポートに変更

;; 2. サーバーのクリーンアップ
(defun cleanup-http-server ()
  (when *test-http-handler*
    (woo:stop *test-http-handler*)
    (setf *test-http-handler* nil)))

;; 3. テスト実行前のクリーンアップ
(setup
  (cleanup-http-server))
```

### 問題: HTTPリクエストがタイムアウトする

**症状:**
```
ERROR: Request timeout after 30 seconds
```

**原因:**
- サーバーが起動していない
- ヘルスチェックが失敗している
- アプリケーションエラー

**解決方法:**

```bash
# 1. サーバー起動の確認
make logs | grep "HTTP server started"

# 2. ヘルスチェックエンドポイントの確認
curl http://localhost:15555/health

# 3. アプリケーションログの確認
make logs | tail -100

# 4. タイムアウト時間の延長
(dex:get url :read-timeout 60) ;; 60秒に延長
```

### 問題: Cookie が設定されない

**症状:**
```
ERROR: Expected Cookie 'session_id' to be set, but it was not found
```

**原因:**
- `Set-Cookie` ヘッダーが正しく生成されていない
- レスポンスヘッダーの形式が不正

**解決方法:**

```lisp
;; 1. レスポンスヘッダーのデバッグ
(defun http-post (path &key json cookie)
  (multiple-value-bind (body status headers ...)
      (dex:post ...)
    ;; デバッグ出力
    (format t "~&[DEBUG] Headers: ~A~%" headers)
    (format t "~&[DEBUG] Set-Cookie: ~A~%" (gethash "set-cookie" headers))
    (values body status headers ...)))

;; 2. Set-Cookieヘッダーの形式確認
;; 期待される形式: ("session_id=...; Path=/; HttpOnly; ...")
```

### 問題: JSON レスポンスのパースエラー

**症状:**
```
ERROR: JSON parse error: unexpected character
```

**原因:**
- レスポンスが JSON 形式でない
- 文字エンコーディングの問題

**解決方法:**

```lisp
;; 1. レスポンスボディのデバッグ
(format t "~&[DEBUG] Response body: ~A~%" body)
(format t "~&[DEBUG] Body type: ~A~%" (type-of body))

;; 2. Content-Type ヘッダーの確認
(format t "~&[DEBUG] Content-Type: ~A~%"
        (gethash "content-type" headers))

;; 3. JSONパースのエラーハンドリング
(handler-case
    (jzon:parse body)
  (error (e)
    (format t "~&[ERROR] JSON parse failed: ~A~%" e)
    (format t "~&[ERROR] Body content: ~A~%" body)
    (error e)))
```

---

## パフォーマンスの問題

### 問題: テストが遅い

**症状:**
```
Test suite completed in 120 seconds (expected < 60s)
```

**原因:**
- パスワードハッシュ化の計算コスト
- 不要なDB接続
- Quicklisp キャッシュ未使用

**解決方法:**

```lisp
;; 1. テスト用に軽量なパスワードハッシュ設定
(defparameter *test-pbkdf2-iterations* 1000) ;; 本番: 600000

;; 2. DB接続の再利用
(defmacro with-test-db (&body body)
  `(if (mito:connected-p)
       (progn ,@body) ;; 既に接続済みなら再利用
       (progn
         (connect-db)
         (unwind-protect
             (progn ,@body)
           (disconnect-db)))))

;; 3. フィクスチャの効率化
;; 不要なフィールドの省略
(create-test-user) ;; email省略 → より高速
```

```bash
# 4. Docker キャッシュの活用
docker volume ls | grep sbcl-cache
# キャッシュボリュームが存在することを確認

# 5. 並列テスト実行（将来実装）
# 現在は非対応
```

### 問題: Docker ビルドが遅い

**症状:**
```
Docker build takes 5+ minutes
```

**原因:**
- レイヤーキャッシュが無効化されている
- 不要なファイルがコピーされている

**解決方法:**

```bash
# 1. .dockerignore の確認
cat .dockerignore
# 以下が含まれていることを確認:
# .git
# node_modules
# var/
# *.fasl

# 2. ビルドキャッシュの確認
docker builder prune  # 古いキャッシュをクリア
docker build --cache-from=voro_test-runner -f Dockerfile.test .

# 3. レイヤーの順序最適化
# Dockerfile.test で、変更頻度の低い行を上に配置
```

---

## デバッグ手法

### 1. ログの確認

```bash
# 全ログを表示
make logs

# 最新100行を表示
make logs | tail -100

# 特定のキーワードで検索
make logs | grep "ERROR"
make logs | grep "http-helper"

# リアルタイムでログを追跡
docker-compose -f docker-compose.test.yml logs -f test-runner
```

### 2. コンテナに入ってデバッグ

```bash
# テストコンテナのシェルに入る
make shell-test

# REPLで個別テスト実行
$ sbcl
* (ql:quickload :voro/test)
* (in-package :voro.test.service)
* (rove:run-test 'test-register-user)

# データベースの確認
$ psql -U voro_test_user -d voro_test
voro_test=# \dt
voro_test=# SELECT * FROM "user";
```

### 3. デバッグ出力の追加

```lisp
;; テストコードにデバッグ出力を追加
(deftest debug-test
  (testing "デバッグ中"
    (with-test-db
      (let ((user (create-test-user)))
        ;; デバッグ出力
        (format t "~&[DEBUG] User: ~A~%" user)
        (format t "~&[DEBUG] User ID: ~A~%" (user-id user))
        (format t "~&[DEBUG] Username: ~A~%" (user-username user))

        ;; テスト続行
        ...))))
```

### 4. ブレークポイントの使用

```lisp
;; Common Lisp デバッガを使用
(deftest debug-with-break
  (testing "ブレークポイント"
    (with-test-db
      (let ((user (create-test-user)))
        (break) ;; ここでデバッガに入る
        (ok (not (null user)))))))
```

### 5. トランザクション無効化（デバッグ用）

```lisp
;; デバッグ時のみ: DBの状態を確認するためトランザクションを無効化
;; ⚠️ 本番コードでは絶対に使用しないこと
(deftest debug-no-transaction
  ;; with-test-db を使わない
  (setup-test-environment)
  (let ((user (create-user :username "debug-user"
                          :password "password123")))
    (format t "~&[DEBUG] User created with ID: ~A~%" (user-id user))
    ;; この後、psql で確認可能
    ))
```

### 6. HTTPリクエストのデバッグ

```lisp
;; リクエスト・レスポンスの詳細を出力
(defun http-post-debug (path &key json cookie)
  (format t "~&[DEBUG] Request: POST ~A~%" path)
  (format t "~&[DEBUG] Body: ~A~%" json)
  (format t "~&[DEBUG] Cookie: ~A~%" cookie)

  (multiple-value-bind (body status headers uri)
      (dex:post (build-test-url path)
               :headers (build-headers cookie)
               :content (jzon:stringify json))

    (format t "~&[DEBUG] Status: ~A~%" status)
    (format t "~&[DEBUG] Response body: ~A~%" body)
    (format t "~&[DEBUG] Headers: ~A~%" headers)

    (values body status headers uri)))
```

---

## よくあるエラーメッセージ

### エラー: "ASDF system not found"

```
ERROR: ASDF could not find system :voro/test
```

**解決方法:**
```bash
# 1. システム定義ファイルの確認
ls -la voro.asd

# 2. ASDF レジストリのリフレッシュ
make clean
make test
```

### エラー: "Package does not exist"

```
ERROR: The name "VORO.TEST.SETUP" does not designate any package
```

**解決方法:**
```lisp
;; 1. パッケージ定義の確認
(defpackage voro.test.setup
  (:use :cl)
  (:export #:with-test-db
           #:setup-test-environment))

;; 2. ロード順序の確認（voro.asd）
:components ((:file "test/setup")  ;; 最初にロード
             (:file "test/fixtures" :depends-on ("test/setup"))
             ...)
```

### エラー: "Slot unbound"

```
ERROR: The slot ID is unbound in the object #<USER>
```

**解決方法:**
```lisp
;; 1. スロットの初期化確認
(defclass user ()
  ((id :col-type :bigserial
       :initarg :id
       :accessor user-id))
  ...)

;; 2. オブジェクト作成時の確認
(let ((user (make-instance 'user
                          :username "test"
                          :password "pass")))
  ;; mito:insert-dao でDBに保存してからIDが割り当てられる
  (mito:insert-dao user)
  (user-id user)) ;; これで安全にアクセス可能
```

---

## ヘルプが必要な場合

以下の情報を含めてイシューを作成してください：

1. **エラーメッセージ**: 完全なスタックトレース
2. **再現手順**: エラーを再現する最小限のコード
3. **環境情報**:
   ```bash
   docker --version
   docker-compose --version
   uname -a
   ```
4. **ログ**: `make logs` の出力
5. **テストファイル**: 問題のあるテストコード

GitHub Issues: `https://github.com/your-repo/voro/issues`

---

## まとめ

- **ログを確認**: `make logs` で詳細なエラー情報を取得
- **環境変数を確認**: テスト実行に必要な環境変数が設定されているか
- **クリーンアップ**: 問題が解決しない場合は `make clean` で完全クリーンアップ
- **コンテナに入る**: `make shell-test` でREPLデバッグ
- **段階的デバッグ**: 問題を切り分けて最小再現コードを作成

詳細なテスト実装ガイドは [backend-guide.md](./backend-guide.md) を参照してください。
