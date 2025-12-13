;;; test/service/auth-test.lisp
;;;
;;; service/auth.lisp のエラーハンドリングテスト
;;; モックを使用して予期せぬエラー発生時の挙動を検証
;;;

(defpackage voro.test.service.auth
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment
                :with-test-db)
  (:import-from :voro.test.helper.mock
                :with-mocked-function)
  (:import-from :voro.service.auth
                :register-user
                :authenticate-user))

(in-package :voro.test.service.auth)

;;;
;;; SA-01: register-user DB接続エラーテスト
;;;

(deftest test-register-user-db-error
  (with-test-environment
    (testing "DB接続エラー時は例外を再スロー"
      ;; create-user がDBエラーをスローするようモック
      ;; find-user-by-username と create-user を両方モックするため、
      ;; 実際のDB操作は発生しない -> with-test-db 不要
      (with-mocked-function (voro.model.user:find-user-by-username
                              (lambda (username)
                                (declare (ignore username))
                                nil))  ;; ユーザーが存在しない（重複なし）
        (with-mocked-function (voro.model.user:create-user
                                (lambda (username password &key email)
                                  (declare (ignore username password email))
                                  (error "Database connection failed")))
          (ok (signals (register-user "newuser" "ValidPass123" :email "test@example.com")
                       'error)
              "DB error should propagate"))))))

;;;
;;; SA-02: register-user セッション作成エラーテスト
;;;

(deftest test-register-user-session-error
  (with-test-environment
    (with-test-db
      (testing "セッション作成エラー時は例外を再スロー"
        ;; ユーザー作成は成功するが、セッション作成で失敗
        ;; create-session がRedisエラーをスローするようモック
        ;; find-user-by-username と create-user は実DBを使用 -> with-test-db 必須
        (with-mocked-function (voro.middleware.session:create-session
                                (lambda (user-id)
                                  (declare (ignore user-id))
                                  (error "Redis connection failed")))
          (ok (signals (register-user "newuser" "ValidPass123" :email "test@example.com")
                       'error)
              "Redis error should propagate"))))))

;;;
;;; SA-03: authenticate-user DB接続エラーテスト
;;;

(deftest test-authenticate-user-db-error
  (with-test-environment
    (testing "DB接続エラー時はNILを返す"
      ;; find-user-by-username がDBエラーをスローするようモック
      ;; with-test-db 不要: 実際のDB操作は発生しない
      (with-mocked-function (voro.model.user:find-user-by-username
                              (lambda (username)
                                (declare (ignore username))
                                (error "Database connection failed")))
        (ok (null (authenticate-user "testuser" "ValidPass123"))
            "DB error should return NIL (fail safely)")))))

;;;
;;; SA-04: authenticate-user セッション作成エラーテスト
;;;

(deftest test-authenticate-user-session-error
  (with-test-environment
    (with-test-db
      (testing "セッション作成エラー時はNILを返す"
        ;; 事前にユーザーを作成（実DBを使用するため with-test-db 必須）
        (voro.model.user:create-user "testuser" "ValidPass123" :email "test@example.com")
        ;; create-session がRedisエラーをスローするようモック
        (with-mocked-function (voro.middleware.session:create-session
                                (lambda (user-id)
                                  (declare (ignore user-id))
                                  (error "Redis connection failed")))
          (ok (null (authenticate-user "testuser" "ValidPass123"))
              "Redis error should return NIL (fail safely)"))))))
