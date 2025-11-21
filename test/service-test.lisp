(defpackage voro.test.service
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment)
  (:import-from :voro.service.auth
                :register-user
                :authenticate-user)
  (:import-from :voro.util.validation
                :validation-error))

(in-package :voro.test.service)

(deftest test-register-user
  (with-test-environment
    (testing "新規ユーザー登録成功"
      (multiple-value-bind (user session-id)
          (register-user "testuser" "password123" :email "test@example.com")
        (ok (not (null user)))
        (ok (not (null session-id)))
        (ok (string= (voro.model.user:user-username user) "testuser"))))

    (testing "重複ユーザー名でエラー"
      (register-user "duplicate" "password123")
      (ok (signals (register-user "duplicate" "password123")
                   'voro.util.validation:validation-error)))

    (testing "パスワードが短すぎる場合エラー"
      (ok (signals (register-user "newuser" "pass1")
                   'voro.util.validation:validation-error)))

    (testing "パスワードに数字が含まれない場合エラー"
      (ok (signals (register-user "newuser" "password")
                   'voro.util.validation:validation-error)))

    (testing "パスワードに英字が含まれない場合エラー"
      (ok (signals (register-user "newuser" "12345678")
                   'voro.util.validation:validation-error)))

    (testing "ユーザー名が短すぎる場合エラー"
      (ok (signals (register-user "ab" "password123")
                   'voro.util.validation:validation-error)))

    (testing "ユーザー名が長すぎる場合エラー"
      (ok (signals (register-user (make-string 51 :initial-element #\a) "password123")
                   'voro.util.validation:validation-error)))

    (testing "ユーザー名に不正な文字が含まれる場合エラー"
      (ok (signals (register-user "user@name" "password123")
                   'voro.util.validation:validation-error)))))

(deftest test-authenticate-user
  (with-test-environment
    ;; テストユーザー作成
    (register-user "logintest" "password123")

    (testing "正しい認証情報でログイン成功"
      (multiple-value-bind (user session-id)
          (authenticate-user "logintest" "password123")
        (ok (not (null user)))
        (ok (not (null session-id)))))

    (testing "間違ったパスワードで失敗"
      (let ((result (authenticate-user "logintest" "wrongpassword")))
        (ok (null result))))))
