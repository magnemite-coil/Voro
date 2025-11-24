(defpackage voro.test.handler.auth
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment
                :with-test-db)
  (:import-from :voro.test.http-helper
                :with-test-server
                :http-post
                :http-get
                :assert-status
                :assert-json-response
                :assert-cookie)
  (:import-from :voro.test.fixtures
                :create-test-user))

(in-package :voro.test.handler.auth)

(deftest auth-register-success-test
  (testing "POST /api/auth/register - 新規ユーザー登録成功"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-post "/api/auth/register"
                        :json (list (cons :|username| "newuser")
                                   (cons :|password| "SecureP@ssw0rd")
                                   (cons :|email| "user@example.com")))

            ;; ステータスコード確認
            (assert-status 200 status)

            ;; JSONレスポンス確認
            (assert-json-response body "data" "user" "id")
            (assert-json-response body "data" "user" "username")

            ;; セッションCookie確認
            (assert-cookie "session_id" headers)))))))

(deftest auth-register-missing-username-test
  (testing "POST /api/auth/register - ユーザー名欠落エラー"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-post "/api/auth/register"
                        :json (list (cons :|password| "password123")))
            (declare (ignore body headers))

            ;; 400 Bad Request
            (assert-status 400 status)))))))

(deftest auth-register-missing-password-test
  (testing "POST /api/auth/register - パスワード欠落エラー"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-post "/api/auth/register"
                        :json (list (cons :|username| "testuser")))
            (declare (ignore body headers))

            ;; 400 Bad Request
            (assert-status 400 status)))))))

(deftest auth-register-duplicate-username-test
  (testing "POST /api/auth/register - ユーザー名重複エラー"
    (with-test-environment
      (with-test-server
        (with-test-db
          ;; 1人目登録
          (http-post "/api/auth/register"
                    :json (list (cons :|username| "testuser")
                               (cons :|password| "password123")
                               (cons :|email| "testuser@example.com")))

          ;; 2人目登録（同じユーザー名）
          (multiple-value-bind (body status headers)
              (http-post "/api/auth/register"
                        :json (list (cons :|username| "testuser")
                                   (cons :|password| "different123")
                                   (cons :|email| "different@example.com")))
            (declare (ignore headers))

            ;; 400 Bad Request
            (assert-status 400 status)

            ;; エラーメッセージ確認
            (ok (search "already exists" body))))))))

(deftest auth-login-success-test
  (testing "POST /api/auth/login - ログイン成功"
    (with-test-environment
      (with-test-server
        (with-test-db
          ;; ユーザー登録
          (http-post "/api/auth/register"
                    :json (list (cons :|username| "loginuser")
                               (cons :|password| "password123")
                               (cons :|email| "loginuser@example.com")))

          ;; ログアウト（セッションクリア）
          (http-post "/api/auth/logout")

          ;; ログイン
          (multiple-value-bind (body status headers)
              (http-post "/api/auth/login"
                        :json (list (cons :|username| "loginuser")
                                   (cons :|password| "password123")))

            (assert-status 200 status)
            (assert-json-response body "data" "user" "username")
            (assert-cookie "session_id" headers)))))))

(deftest auth-login-invalid-username-test
  (testing "POST /api/auth/login - 存在しないユーザー"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-post "/api/auth/login"
                        :json (list (cons :|username| "nonexistent")
                                   (cons :|password| "password123")))
            (declare (ignore body headers))

            ;; 401 Unauthorized
            (assert-status 401 status)))))))

(deftest auth-login-invalid-password-test
  (testing "POST /api/auth/login - パスワード不一致"
    (with-test-environment
      (with-test-server
        (with-test-db
          ;; ユーザー登録
          (http-post "/api/auth/register"
                    :json (list (cons :|username| "user1")
                               (cons :|password| "correct123")
                               (cons :|email| "user1@example.com")))

          ;; 間違ったパスワードでログイン
          (multiple-value-bind (body status headers)
              (http-post "/api/auth/login"
                        :json (list (cons :|username| "user1")
                                   (cons :|password| "wrong")))
            (declare (ignore headers))

            ;; 401 Unauthorized
            (assert-status 401 status)
            (ok (search "Invalid" body))))))))

(deftest auth-login-missing-username-test
  (testing "POST /api/auth/login - ユーザー名欠落エラー"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-post "/api/auth/login"
                        :json (list (cons :|password| "password123")))
            (declare (ignore body headers))

            ;; 400 Bad Request
            (assert-status 400 status)))))))

(deftest auth-login-missing-password-test
  (testing "POST /api/auth/login - パスワード欠落エラー"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-post "/api/auth/login"
                        :json (list (cons :|username| "testuser")))
            (declare (ignore body headers))

            ;; 400 Bad Request
            (assert-status 400 status)))))))

(deftest auth-logout-success-test
  (testing "POST /api/auth/logout - ログアウト成功"
    (with-test-environment
      (with-test-server
        (with-test-db
          ;; ユーザー登録（セッション取得）
          (http-post "/api/auth/register"
                    :json (list (cons :|username| "logoutuser")
                               (cons :|password| "password123")
                               (cons :|email| "logoutuser@example.com")))

          ;; ログアウト
          (multiple-value-bind (body status headers)
              (http-post "/api/auth/logout")

            (assert-status 200 status)
            (assert-json-response body "data" "message")

            ;; Cookie削除確認（Max-Age=0）
            (let* ((set-cookie-raw (or (gethash "set-cookie" headers)
                                       (gethash "Set-Cookie" headers)))
                   (set-cookie (if (listp set-cookie-raw)
                                   (first set-cookie-raw)
                                   set-cookie-raw)))
              (ok (and set-cookie (search "Max-Age=0" set-cookie))
                  "Session cookie cleared with Max-Age=0"))))))))
