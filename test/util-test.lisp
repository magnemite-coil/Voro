(defpackage voro.test.util
  (:use :cl :rove)
  (:import-from :voro.util.validation
                :validate-password
                :validate-username
                :validate-email
                :validation-error)
  (:import-from :voro.util.crypto
                :hash-password
                :verify-password))

(in-package :voro.test.util)

;;; バリデーションテスト

(deftest test-validate-password
  (testing "有効なパスワード"
    (ok (validate-password "password123"))
    (ok (validate-password "testPass1")))

  (testing "パスワードが短すぎる（8文字未満）"
    (ok (signals (validate-password "pass1") 'validation-error)))

  (testing "英字が含まれていない"
    (ok (signals (validate-password "12345678") 'validation-error)))

  (testing "数字が含まれていない"
    (ok (signals (validate-password "password") 'validation-error))))

(deftest test-validate-username
  (testing "有効なユーザー名"
    (ok (validate-username "testuser"))
    (ok (validate-username "user123"))
    (ok (validate-username "test_user")))

  (testing "ユーザー名が短すぎる（3文字未満）"
    (ok (signals (validate-username "ab") 'validation-error)))

  (testing "ユーザー名が長すぎる（50文字超過）"
    (ok (signals (validate-username (make-string 51 :initial-element #\a))
                 'validation-error)))

  (testing "英字で始まらない"
    (ok (signals (validate-username "1user") 'validation-error))
    (ok (signals (validate-username "_user") 'validation-error)))

  (testing "不正な文字が含まれる"
    (ok (signals (validate-username "user@name") 'validation-error))
    (ok (signals (validate-username "user-name") 'validation-error))
    (ok (signals (validate-username "user name") 'validation-error))))

(deftest test-validate-email
  (testing "有効なメールアドレス"
    (ok (validate-email "test@example.com"))
    (ok (validate-email "user.name@example.co.jp"))
    (ok (validate-email "user+tag@example.com")))

  (testing "NILは拒否される（必須項目）"
    (ok (signals (validate-email nil) 'validation-error)))

  (testing "長すぎるメールアドレス（254文字超過）"
    (ok (signals (validate-email (format nil "~A@example.com" (make-string 245 :initial-element #\a)))
                 'validation-error)))

  (testing "不正な形式"
    (ok (signals (validate-email "invalid") 'validation-error))
    (ok (signals (validate-email "invalid@") 'validation-error))
    (ok (signals (validate-email "@example.com") 'validation-error)))

  (testing "連続ドット"
    (ok (signals (validate-email "user..name@example.com") 'validation-error)))

  (testing "先頭・末尾のドット"
    (ok (signals (validate-email ".user@example.com") 'validation-error))
    (ok (signals (validate-email "user.@example.com") 'validation-error)))

  (testing "複数の@記号"
    (ok (signals (validate-email "user@@example.com") 'validation-error))
    (ok (signals (validate-email "user@example@com") 'validation-error))))

;;; 暗号化テスト

(deftest test-password-hashing
  (testing "パスワードハッシュ化と検証"
    (let* ((password "testPassword123")
           (hashed (hash-password password)))
      (ok (not (string= password hashed)))
      (ok (verify-password password hashed))))

  (testing "異なるパスワードで検証失敗"
    (let ((hashed (hash-password "password123")))
      (ok (not (verify-password "wrongpassword" hashed)))))

  (testing "同じパスワードでも異なるソルトが使用される"
    (let ((hash1 (hash-password "password123"))
          (hash2 (hash-password "password123")))
      (ok (not (string= hash1 hash2))))))
