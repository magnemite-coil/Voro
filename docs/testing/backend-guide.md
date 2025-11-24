# バックエンドテスト開発ガイド

このドキュメントでは、Voroプロジェクトのバックエンドテストの書き方とベストプラクティスを説明します。

## 📋 目次

1. [テスト環境の理解](#テスト環境の理解)
2. [テストの書き方](#テストの書き方)
3. [HTTP統合テスト](#http統合テスト)
4. [テストフィクスチャ](#テストフィクスチャ)
5. [ベストプラクティス](#ベストプラクティス)
6. [よくあるパターン](#よくあるパターン)

---

## テスト環境の理解

### テストアーキテクチャ

```
┌─────────────────────────────────────┐
│   Docker Compose Environment        │
├─────────────────────────────────────┤
│ ┌────────────┐  ┌───────────────┐  │
│ │ PostgreSQL │  │    Redis      │  │
│ │  (voro_test)  │  │   (DB 1)      │  │
│ └────────────┘  └───────────────┘  │
│         ▲               ▲           │
│         │               │           │
│ ┌───────┴───────────────┴────────┐ │
│ │     Test Runner (SBCL)         │ │
│ │  ┌──────────────────────────┐  │ │
│ │  │  Rove Test Framework     │  │ │
│ │  └──────────────────────────┘  │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### 8層防御システム

テスト実行時、本番データベースを保護するための8層の防御機構が動作します：

```lisp
;; test/setup.lisp で実装
(defun verify-test-database ()
  "8層防御による本番DB保護"
  ;; 層1-3: 環境変数チェック
  ;; 層4-5: DB名検証
  ;; 層6: テーブル存在確認
  )

(defmacro with-test-db (&body body)
  "トランザクションベースのテスト分離（層7-8）"
  ;; 自動ロールバックによる副作用ゼロ
  )
```

---

## テストの書き方

### 基本構造

Voroのテストは[Rove](https://github.com/fukamachi/rove)フレームワークを使用します。

```lisp
(defpackage voro.test.example
  (:use :cl :rove)
  (:import-from :voro.test.setup
                #:with-test-db)
  (:import-from :voro.test.fixtures
                #:create-test-user))

(in-package :voro.test.example)

(deftest test-example-feature
  (testing "機能の説明"
    (with-test-db
      ;; Arrange: テストデータの準備
      (let ((user (create-test-user)))

        ;; Act: テスト対象の実行
        (let ((result (some-function user)))

          ;; Assert: 結果の検証
          (ok (not (null result)))
          (ok (string= (get-username result) "testuser0")))))))
```

### Util層テストの例

```lisp
;; test/util-test.lisp
(deftest test-validate-email
  (testing "有効なメールアドレス"
    (ok (validate-email "test@example.com"))
    (ok (validate-email "user.name@example.co.jp")))

  (testing "不正な形式"
    (ok (signals (validate-email "invalid")
                 'validation-error))
    (ok (signals (validate-email "invalid@")
                 'validation-error))))
```

### Model層テストの例

```lisp
;; test/model-test.lisp
(deftest test-user-model
  (testing "ユーザー作成とクエリ"
    (with-test-db
      ;; トランザクション内でテスト実行
      ;; テスト終了後は自動ロールバック
      (let ((user (create-user :username "testuser"
                               :password "hashed-password"
                               :email "test@example.com")))
        (ok (not (null user)))
        (ok (string= (user-username user) "testuser"))))))
```

### Service層テストの例

```lisp
;; test/service-test.lisp
(deftest test-register-user
  (testing "新規ユーザー登録成功"
    (with-test-db
      (multiple-value-bind (user session-id)
          (register-user "newuser" "password123"
                        :email "new@example.com")
        (ok (not (null user)))
        (ok (not (null session-id)))
        (ok (string= (user-username user) "newuser")))))

  (testing "重複ユーザー名でエラー"
    (with-test-db
      (register-user "duplicate" "password123")
      (ok (signals (register-user "duplicate" "password123")
                   'validation-error)))))
```

---

## HTTP統合テスト

### HTTP Helperの使い方

HTTP統合テストには `test/http-helper.lisp` のヘルパー関数を使用します。

#### サーバー管理

```lisp
(deftest auth-api-test
  (testing "認証APIテスト"
    (with-test-db
      (with-test-http-server ()
        ;; サーバーが自動的に起動・停止される
        (multiple-value-bind (body status headers)
            (http-post "/api/auth/register"
                      :json `(("username" . "testuser")
                             ("password" . "password123")))
          (assert-status 200 status)
          (assert-json-value "testuser" body "data" "user" "username"))))))
```

#### HTTPリクエストヘルパー

```lisp
;; GET リクエスト
(http-get "/api/users/1")

;; POST リクエスト
(http-post "/api/auth/register"
          :json '(("username" . "user")
                 ("password" . "pass123")))

;; PUT リクエスト
(http-put "/api/users/1"
         :json '(("email" . "new@example.com")))

;; DELETE リクエスト
(http-delete "/api/users/1")

;; 認証付きリクエスト
(http-get "/api/profile" :cookie session-cookie)
```

#### レスポンス検証

```lisp
;; ステータスコード検証
(assert-status 200 status)
(assert-status 400 status)

;; JSON値の検証
(assert-json-value "expected-value" body "key" "nested-key")
(assert-json-value 123 body "data" "id")

;; Cookieの検証
(assert-cookie-set "session_id" headers)

;; JSONキー存在確認
(ok (json-has-key-p body "data" "user"))
```

### 認証が必要なエンドポイントのテスト

```lisp
(deftest protected-endpoint-test
  (testing "認証が必要なエンドポイント"
    (with-test-db
      (with-test-http-server ()
        ;; ユーザー登録してセッション取得
        (let* ((user (create-test-user :username "authuser"
                                      :password "password123"))
               (session-cookie (create-test-session (user-id user))))

          ;; 認証付きリクエスト
          (multiple-value-bind (body status headers)
              (http-get "/api/profile"
                       :cookie session-cookie)
            (assert-status 200 status)
            (assert-json-value "authuser" body "data" "username")))))))
```

### 完全なHTTP統合テストの例

```lisp
(deftest auth-register-success-test
  (testing "POST /api/auth/register - 新規ユーザー登録成功"
    (with-test-db
      (with-test-http-server ()
        ;; リクエスト実行
        (multiple-value-bind (body status headers)
            (http-post "/api/auth/register"
                      :json `(("username" . "newuser")
                             ("password" . "password123")
                             ("email" . "new@example.com")))

          ;; ステータスコード検証
          (assert-status 200 status)

          ;; レスポンスボディ検証
          (assert-json-value "newuser" body "data" "user" "username")
          (ok (json-has-key-p body "data" "user" "id"))

          ;; Cookie検証
          (assert-cookie-set "session_id" headers))))))
```

---

## テストフィクスチャ

### フィクスチャ関数

`test/fixtures.lisp` には、テストデータ作成のためのヘルパー関数があります。

#### ユーザーフィクスチャ

```lisp
;; 自動インクリメントユーザー名
(let ((user1 (create-test-user)))
  ;; username: "testuser0", password: "password123"
  )

(let ((user2 (create-test-user)))
  ;; username: "testuser1", password: "password123"
  ;; ユーザー名が自動的にインクリメント
  )

;; カスタムパラメータ
(let ((user (create-test-user :username "custom"
                             :password "custom123"
                             :email "custom@example.com")))
  ;; カスタムパラメータで作成
  )

;; 複数ユーザー作成
(let ((users (create-test-users 5)))
  ;; testuser0 ~ testuser4 を一括作成
  )
```

#### セッションフィクスチャ

```lisp
(let* ((user (create-test-user))
       (session-cookie (create-test-session (user-id user))))
  ;; session-cookie: "session_id=<session-id>"
  ;; HTTPリクエストで使用可能
  )
```

### フィクスチャ使用例

```lisp
(deftest user-interaction-test
  (testing "ユーザー間のインタラクション"
    (with-test-db
      ;; 複数ユーザー作成
      (let ((users (create-test-users 3)))
        (let ((user1 (first users))
              (user2 (second users))
              (user3 (third users)))

          ;; テストロジック
          (ok (not (equal (user-id user1)
                         (user-id user2)))))))))
```

---

## ベストプラクティス

### 1. テストの独立性を保つ

```lisp
;; ❌ 悪い例: テスト間で状態を共有
(defparameter *shared-user* nil)

(deftest test-1
  (setf *shared-user* (create-test-user))
  ;; test-2 に依存
  )

(deftest test-2
  ;; test-1 の実行順序に依存
  (ok (not (null *shared-user*))))

;; ✅ 良い例: 各テストで独立してセットアップ
(deftest test-1
  (with-test-db
    (let ((user (create-test-user)))
      ;; 独立したテスト
      )))

(deftest test-2
  (with-test-db
    (let ((user (create-test-user)))
      ;; 独立したテスト
      )))
```

### 2. with-test-db を必ず使用する

```lisp
;; ❌ 悪い例: トランザクション分離なし
(deftest test-without-transaction
  (let ((user (create-user :username "test")))
    ;; テストデータがDBに残る！
    ))

;; ✅ 良い例: トランザクション分離
(deftest test-with-transaction
  (with-test-db
    (let ((user (create-user :username "test")))
      ;; テスト終了後は自動ロールバック
      )))
```

### 3. 説明的なテスト名を使用

```lisp
;; ❌ 悪い例
(testing "test 1"
  ...)

;; ✅ 良い例
(testing "POST /api/auth/register - ユーザー名が重複している場合は400エラー"
  ...)
```

### 4. エッジケースをカバーする

```lisp
(deftest test-validate-username
  (testing "正常系"
    (ok (validate-username "validuser")))

  (testing "境界値 - 最小長（3文字）"
    (ok (validate-username "abc")))

  (testing "境界値 - 最大長（50文字）"
    (ok (validate-username (make-string 50 :initial-element #\a))))

  (testing "異常系 - 短すぎる（2文字）"
    (ok (signals (validate-username "ab") 'validation-error)))

  (testing "異常系 - 長すぎる（51文字）"
    (ok (signals (validate-username (make-string 51 :initial-element #\a))
                'validation-error))))
```

### 5. Arrange-Act-Assert パターン

```lisp
(deftest test-user-authentication
  (testing "正しい認証情報でログイン成功"
    (with-test-db
      ;; Arrange: テストデータの準備
      (let ((user (create-test-user :username "testuser"
                                   :password "password123")))

        ;; Act: テスト対象の実行
        (multiple-value-bind (result session-id)
            (authenticate-user "testuser" "password123")

          ;; Assert: 結果の検証
          (ok (not (null result)))
          (ok (not (null session-id)))
          (ok (string= (user-username result) "testuser")))))))
```

---

## よくあるパターン

### パターン1: CRUD操作のテスト

```lisp
(deftest test-user-crud
  (testing "Create"
    (with-test-db
      (let ((user (create-user ...)))
        (ok (not (null user))))))

  (testing "Read"
    (with-test-db
      (let* ((user (create-user ...))
             (found (find-user-by-username (user-username user))))
        (ok (not (null found))))))

  (testing "Update"
    (with-test-db
      (let* ((user (create-user ...))
             (updated (update-user user :email "new@example.com")))
        (ok (string= (user-email updated) "new@example.com")))))

  (testing "Delete"
    (with-test-db
      (let ((user (create-user ...)))
        (delete-user user)
        (ok (null (find-user-by-id (user-id user))))))))
```

### パターン2: バリデーションエラーのテスト

```lisp
(deftest test-validation-errors
  (testing "必須パラメータ欠落"
    (ok (signals (validate-user-input nil "password")
                'validation-error)))

  (testing "不正な形式"
    (ok (signals (validate-user-input "invalid@username" "password")
                'validation-error)))

  (testing "長さ制約違反"
    (ok (signals (validate-user-input "ab" "password")
                'validation-error))))
```

### パターン3: HTTPエンドポイントのテスト

```lisp
(deftest test-http-endpoint
  (testing "正常系 - 200 OK"
    (with-test-db
      (with-test-http-server ()
        (multiple-value-bind (body status headers)
            (http-get "/api/endpoint")
          (assert-status 200 status)))))

  (testing "異常系 - 400 Bad Request"
    (with-test-db
      (with-test-http-server ()
        (multiple-value-bind (body status headers)
            (http-post "/api/endpoint" :json '())
          (assert-status 400 status)))))

  (testing "異常系 - 401 Unauthorized"
    (with-test-db
      (with-test-http-server ()
        (multiple-value-bind (body status headers)
            (http-get "/api/protected")
          (assert-status 401 status))))))
```

---

## デバッグ Tips

### 1. ログ出力でデバッグ

```lisp
(testing "デバッグ中"
  (with-test-db
    (let ((user (create-test-user)))
      ;; ログ出力
      (format t "~&[DEBUG] User: ~A~%" user)
      (format t "~&[DEBUG] User ID: ~A~%" (user-id user))

      ;; テスト続行
      ...)))
```

### 2. REPL でテスト実行

```bash
# Docker コンテナのシェルに入る
make shell-test

# REPL で個別テスト実行
(ql:quickload :voro/test)
(in-package :voro.test.service)
(run-test 'test-register-user)
```

### 3. トランザクションを無効化してDB確認

```lisp
;; デバッグ時のみ: トランザクションなしでテスト
;; （本番コードでは使用禁止）
(deftest debug-test
  ;; with-test-db を使わない
  (setup-test-environment)
  (let ((user (create-user ...)))
    ;; DBに残るので手動確認可能
    (format t "~&User ID: ~A~%" (user-id user))))
```

---

## まとめ

- **`with-test-db`** を常に使用してトランザクション分離を保証
- **フィクスチャ関数** を活用してテストデータ作成を簡素化
- **HTTP Helper** を使用して統合テストを効率的に記述
- **Arrange-Act-Assert** パターンでテストを構造化
- **エッジケース** を含む包括的なテストを記述

詳細なトラブルシューティングは [troubleshooting.md](./troubleshooting.md) を参照してください。
