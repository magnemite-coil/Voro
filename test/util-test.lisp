(defpackage voro.test.util
  (:use :cl :rove)
  (:import-from :voro.util.validation
                :validate-password
                :validate-username
                :validate-email
                :validation-error)
  (:import-from :voro.util.crypto
                :hash-password
                :verify-password)
  (:import-from :voro.util.json
                :alist-to-hash-table-recursive
                :plist-to-hash-table
                :to-json
                :to-json-plist
                :parse-json)
  (:import-from :voro.util.request
                :get-body-param))

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

;;; JSON変換テスト

(deftest json-alist-to-hash-table-test ()
  "alist-to-hash-table-recursive のテスト"
  (testing "単純なalist"
    (let ((result (alist-to-hash-table-recursive
                   '((:|name| . "test") (:|value| . 123)))))
      (ok (hash-table-p result))
      (ok (equal "test" (gethash "name" result)))
      (ok (= 123 (gethash "value" result)))))

  (testing "ネストしたalist"
    (let ((result (alist-to-hash-table-recursive
                   '((:|user| . ((:|id| . 1) (:|name| . "test")))))))
      (ok (hash-table-p result))
      (ok (hash-table-p (gethash "user" result)))
      (ok (= 1 (gethash "id" (gethash "user" result))))))

  (testing "トップレベルの空リストは空オブジェクトになる"
    (let ((result (alist-to-hash-table-recursive nil)))
      (ok (hash-table-p result))
      (ok (= 0 (hash-table-count result)))))

  (testing "alistの値としてのnilはfalseになる"
    (let ((result (alist-to-hash-table-recursive
                   '((:|success| . nil)))))
      (ok (hash-table-p result))
      (ok (null (gethash "success" result))))))

(deftest json-plist-to-hash-table-test ()
  "plist-to-hash-table のテスト"
  (testing "通常のplist"
    (let ((result (plist-to-hash-table
                   '(:|user_id| 123 :|title| "test"))))
      (ok (hash-table-p result))
      (ok (= 123 (gethash "user_id" result)))
      (ok (equal "test" (gethash "title" result)))))

  (testing "空のplist"
    (let ((result (plist-to-hash-table nil)))
      (ok (hash-table-p result))
      (ok (= 0 (hash-table-count result))))))

(deftest json-to-json-test ()
  "to-json のテスト"
  (testing "単純なalist"
    (let ((json (to-json '((:|name| . "test")))))
      (ok (stringp json))
      (ok (search "name" json))
      (ok (search "test" json))))

  (testing "ネストしたalist"
    (let ((json (to-json
                 '((:|success| . t)
                   (:|data| . ((:|id| . 1)))))))
      (ok (stringp json))
      (ok (search "success" json))
      (ok (search "data" json))))

  (testing "true/falseの出力"
    (let ((json (to-json
                 '((:|enabled| . t)
                   (:|disabled| . nil)))))
      (ok (search "true" json))
      ;; alistの値としてのnilはfalseになる
      (ok (search "false" json)))))

(deftest json-to-json-plist-test ()
  "to-json-plist のテスト"
  (testing "単純なplist"
    (let ((json (to-json-plist '(:|name| "test" :|value| 123))))
      (ok (stringp json))
      (ok (search "name" json))
      (ok (search "test" json))
      (ok (search "value" json))))

  (testing "空のplist"
    (let ((json (to-json-plist nil)))
      (ok (stringp json))
      (ok (equal "{}" json)))))

(deftest json-parse-json-test ()
  "parse-json のテスト"
  (testing "オブジェクトのパース"
    (let ((result (parse-json "{\"name\":\"test\",\"value\":123}")))
      (ok (hash-table-p result))
      (ok (equal "test" (gethash "name" result)))
      (ok (= 123 (gethash "value" result)))))

  (testing "配列のパース"
    (let ((result (parse-json "[1,2,3]")))
      (ok (vectorp result))
      (ok (= 3 (length result)))))

  (testing "プリミティブ値のパース"
    (ok (eq t (parse-json "true")))
    (ok (eq nil (parse-json "false")))
    (ok (eq 'null (parse-json "null")))
    (ok (= 42 (parse-json "42")))))

;;; リクエストユーティリティテスト

(deftest test-get-body-param
  (testing "キーが存在する場合は値を返す"
    (let ((params '(("username" . "testuser") ("email" . "test@example.com"))))
      (ok (equal "testuser" (get-body-param params "username")))
      (ok (equal "test@example.com" (get-body-param params "email")))))

  (testing "キーが存在しない場合はNILを返す"
    (let ((params '(("username" . "testuser"))))
      (ok (null (get-body-param params "nonexistent")))))

  (testing "空のalistの場合はNILを返す"
    (ok (null (get-body-param nil "anykey"))))

  (testing "キーの比較は文字列比較（string=）"
    (let ((params '(("Username" . "test"))))
      ;; 大文字小文字を区別する
      (ok (null (get-body-param params "username")))
      (ok (equal "test" (get-body-param params "Username"))))))

;;;
;;; validate-password 追加テスト（境界値・特殊ケース）
;;;

(deftest test-validate-password-edge-cases
  (testing "境界値テスト - 7文字はNG"
    (ok (signals (validate-password "pass12a") 'validation-error)
        "7 characters should fail"))

  (testing "境界値テスト - 8文字はOK"
    (ok (validate-password "pass123a")
        "8 characters should pass"))

  (testing "長いパスワード（100文字）はOK"
    (let ((long-password (concatenate 'string
                                       (make-string 92 :initial-element #\a)
                                       "12345678")))
      (ok (validate-password long-password)
          "100 characters should pass")))

  (testing "特殊記号を含むパスワードはOK"
    (ok (validate-password "p@ssw0rd!")
        "Special characters should pass")
    (ok (validate-password "Test#123$")
        "Multiple special characters should pass"))

  (testing "空白を含むパスワードはOK"
    (ok (validate-password "pass 123a")
        "Spaces should be allowed"))

  (testing "日本語+英字+数字はOK"
    (ok (validate-password "パスワード123a")
        "Japanese with letters and numbers should pass"))

  (testing "数字のみ（英字なし）はNG"
    (ok (signals (validate-password "12345678") 'validation-error)
        "Numbers only should fail"))

  (testing "英字のみ（数字なし）はNG"
    (ok (signals (validate-password "abcdefgh") 'validation-error)
        "Letters only should fail")))

;;;
;;; validate-username 追加テスト（境界値・特殊ケース）
;;;

(deftest test-validate-username-edge-cases
  (testing "境界値テスト - 2文字はNG"
    (ok (signals (validate-username "ab") 'validation-error)
        "2 characters should fail"))

  (testing "境界値テスト - 3文字はOK"
    (ok (validate-username "abc")
        "3 characters should pass"))

  (testing "境界値テスト - 50文字はOK"
    ;; 先頭は英字必須のため "a" + 49文字 = 50文字
    (let ((username-50 (concatenate 'string "a" (make-string 49 :initial-element #\b))))
      (ok (validate-username username-50)
          "50 characters should pass")))

  (testing "境界値テスト - 51文字はNG"
    ;; 先頭は英字必須のため "a" + 50文字 = 51文字
    (let ((username-51 (concatenate 'string "a" (make-string 50 :initial-element #\b))))
      (ok (signals (validate-username username-51) 'validation-error)
          "51 characters should fail")))

  (testing "アンダースコアを含むユーザー名はOK"
    (ok (validate-username "user_name_123")
        "Underscores should be allowed"))

  (testing "ハイフンを含むユーザー名はNG"
    (ok (signals (validate-username "user-name") 'validation-error)
        "Hyphens should not be allowed"))

  (testing "日本語ユーザー名はNG"
    (ok (signals (validate-username "ユーザー") 'validation-error)
        "Japanese characters should not be allowed"))

  (testing "数字で始まるユーザー名はNG"
    (ok (signals (validate-username "123user") 'validation-error)
        "Starting with number should not be allowed")))

;;;
;;; validate-email 追加テスト（境界値）
;;;
;;; 注: RFC 5321ではローカル部は64文字まで。この値を超えると長さ超過ではなく
;;;     ローカル部フォーマットエラーになる可能性があるため、ローカル部は64文字に固定し
;;;     ドメイン部の長さを調整して総文字数の境界値をテストする。
;;;

(deftest test-validate-email-edge-cases
  (testing "境界値テスト - 254文字はOK"
    ;; ローカル部64文字 + @ + ドメイン部185文字 + .com(4文字) = 254文字
    (let ((email (format nil "~A@~A.com"
                         (make-string 64 :initial-element #\a)
                         (make-string 185 :initial-element #\b))))
      (ok (validate-email email)
          "254 characters should pass")))

  (testing "境界値テスト - 255文字はNG"
    ;; ローカル部64文字 + @ + ドメイン部186文字 + .com(4文字) = 255文字
    (let ((email (format nil "~A@~A.com"
                         (make-string 64 :initial-element #\a)
                         (make-string 186 :initial-element #\b))))
      (ok (signals (validate-email email) 'validation-error)
          "255 characters should fail")))

  (testing "サブドメインを含むメールアドレスはOK"
    (ok (validate-email "user@mail.example.com")
        "Subdomain should pass")
    (ok (validate-email "user@sub.domain.example.co.jp")
        "Multiple subdomains should pass"))

  (testing "@で始まるメールアドレスはNG"
    (ok (signals (validate-email "@example.com") 'validation-error)
        "Email starting with @ should fail"))

  (testing "@で終わるメールアドレスはNG"
    (ok (signals (validate-email "user@") 'validation-error)
        "Email ending with @ should fail")))
