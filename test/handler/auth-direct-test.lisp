(defpackage voro.test.handler.auth-direct
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment
                :with-test-db)
  (:import-from :voro.test.direct-call-helper
                :direct-post
                :assert-direct-status
                :assert-direct-json
                :assert-direct-cookie
                :extract-session-id)  ;; 共通ヘルパーを使用
  (:import-from :voro.test.fixtures
                :create-test-user))

(in-package :voro.test.handler.auth-direct)

;;;
;;; 登録テスト（直接呼び出し）
;;;

(deftest auth-register-direct-success-test
  (testing "POST /api/auth/register - 新規登録成功（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (body status headers)
            (direct-post "/api/auth/register"
                        :json (list (cons :|username| "newuser")
                                   (cons :|password| "SecureP@ssw0rd")
                                   (cons :|email| "user@example.com")))

          ;; ステータスコード検証
          (assert-direct-status 200 status)

          ;; JSONレスポンス検証
          (assert-direct-json body "data" "user" "id")
          (assert-direct-json body "data" "user" "username")

          ;; セッションCookie検証
          (assert-direct-cookie "session_id" headers))))))

(deftest auth-register-direct-missing-username-test
  (testing "POST /api/auth/register - ユーザー名欠落エラー（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (body status headers)
            (direct-post "/api/auth/register"
                        :json (list (cons :|password| "password123")))
          (declare (ignore body headers))

          ;; 400 Bad Request
          (assert-direct-status 400 status))))))

(deftest auth-register-direct-duplicate-test
  (testing "POST /api/auth/register - ユーザー名重複エラー（直接呼び出し）"
    (with-test-environment
      (with-test-db
        ;; 1人目登録
        (direct-post "/api/auth/register"
                    :json (list (cons :|username| "testuser")
                               (cons :|password| "password123")
                               (cons :|email| "test@example.com")))

        ;; 2人目登録（同じユーザー名）
        (multiple-value-bind (body status headers)
            (direct-post "/api/auth/register"
                        :json (list (cons :|username| "testuser")
                                   (cons :|password| "different123")
                                   (cons :|email| "different@example.com")))
          (declare (ignore headers))

          ;; 400 Bad Request
          (assert-direct-status 400 status)

          ;; エラーメッセージ確認
          (ok (search "Registration failed" body)))))))

;;;
;;; ログインテスト（直接呼び出し）
;;;

(deftest auth-login-direct-success-test
  (testing "POST /api/auth/login - ログイン成功（直接呼び出し）"
    (with-test-environment
      (with-test-db
        ;; ユーザー登録
        (direct-post "/api/auth/register"
                    :json (list (cons :|username| "loginuser")
                               (cons :|password| "password123")
                               (cons :|email| "login@example.com")))

        ;; ログイン
        (multiple-value-bind (body status headers)
            (direct-post "/api/auth/login"
                        :json (list (cons :|username| "loginuser")
                                   (cons :|password| "password123")))

          (assert-direct-status 200 status)
          (assert-direct-json body "data" "user" "username")
          (assert-direct-cookie "session_id" headers))))))

(deftest auth-login-direct-invalid-password-test
  (testing "POST /api/auth/login - パスワード不一致（直接呼び出し）"
    (with-test-environment
      (with-test-db
        ;; ユーザー登録
        (direct-post "/api/auth/register"
                    :json (list (cons :|username| "user1")
                               (cons :|password| "correct123")
                               (cons :|email| "user1@example.com")))

        ;; 間違ったパスワードでログイン
        (multiple-value-bind (body status headers)
            (direct-post "/api/auth/login"
                        :json (list (cons :|username| "user1")
                                   (cons :|password| "wrong")))
          (declare (ignore headers))

          ;; 401 Unauthorized
          (assert-direct-status 401 status)
          (ok (search "Invalid" body)))))))

;;;
;;; ログアウトテスト（直接呼び出し）
;;;

(deftest auth-logout-direct-success-test
  (testing "POST /api/auth/logout - ログアウト成功（直接呼び出し）"
    (with-test-environment
      (with-test-db
        ;; ユーザー登録（セッション取得）
        (multiple-value-bind (body status headers)
            (direct-post "/api/auth/register"
                        :json (list (cons :|username| "logoutuser")
                                   (cons :|password| "password123")
                                   (cons :|email| "logout@example.com")))
          (declare (ignore body status))

          ;; Set-Cookieからセッションを取得（共通ヘルパー使用）
          (let ((session-id (extract-session-id headers)))

            ;; ログアウト
            (multiple-value-bind (logout-body logout-status logout-headers)
                (direct-post "/api/auth/logout"
                            :cookies (list (cons "session_id" session-id)))

              (assert-direct-status 200 logout-status)
              (assert-direct-json logout-body "data" "message")

              ;; Cookie削除確認（Max-Age=0）
              (let ((set-cookie (cdr (assoc "set-cookie" logout-headers :test #'string=))))
                (ok (and set-cookie (search "Max-Age=0" set-cookie))
                    "Session cookie cleared with Max-Age=0")))))))))
