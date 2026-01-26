(defpackage voro.test.util
  (:use :cl :rove)
  (:import-from :voro.util.validation
                :validate-password
                :validate-username
                :validate-email
                :validation-error
                :authorization-error
                :not-found-error)
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
                :get-body-param
                :get-query-param
                :parse-integer-param)
  (:import-from :cl-ppcre
                :scan))

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

;;;
;;; hash-password / verify-password 追加テスト（test/util-test.lisp に追加）
;;;
;;; 注意:
;;;   - ハッシュ形式検証で使用する 100000 は src/util/crypto.lisp の
;;;     *pbkdf2-iterations* 定数と同じ値。イテレーション回数を変更した場合は
;;;     このテストも更新が必要
;;;

(deftest test-hash-password-edge-cases
  (testing "空文字パスワードのハッシュ化"
    (let ((hashed (hash-password "")))
      (ok (stringp hashed)
          "Empty password can be hashed")
      (ok (> (length hashed) 0)
          "Hash is not empty")))

  (testing "日本語パスワードのハッシュ化"
    (let ((hashed (hash-password "パスワード123abc")))
      (ok (stringp hashed)
          "Japanese password can be hashed")
      (ok (verify-password "パスワード123abc" hashed)
          "Japanese password can be verified")))

  (testing "特殊記号を含むパスワードのハッシュ化"
    (let* ((special-password "P@ss!#$%^&*()_+-=[]{}|;':\",./<>?")
           (hashed (hash-password special-password)))
      (ok (stringp hashed)
          "Password with special characters can be hashed")
      (ok (verify-password special-password hashed)
          "Password with special characters can be verified")))

  (testing "非常に長いパスワードのハッシュ化"
    (let* ((long-password (make-string 1000 :initial-element #\a))
           (hashed (hash-password long-password)))
      (ok (stringp hashed)
          "Long password can be hashed")
      (ok (verify-password long-password hashed)
          "Long password can be verified")))

  (testing "ハッシュ形式の検証（PBKDF2形式）"
    ;; フォーマット: PBKDF2$SHA256:100000$<salt>$<hash>
    ;; イテレーション数を固定値で検証し、意図しない変更を検出
    ;; 注: 100000 は src/util/crypto.lisp の *pbkdf2-iterations* と同じ値
    ;; 注: SHA256 は ironclad が大文字で出力する
    (let ((hashed (hash-password "testpassword")))
      (ok (scan "^PBKDF2\\$SHA256:100000\\$" hashed)
          "Hash should be in PBKDF2$SHA256:100000$ format with correct iteration count"))))

(deftest test-verify-password-edge-cases
  (testing "空文字パスワードの検証"
    (let ((hashed (hash-password "")))
      (ok (verify-password "" hashed)
          "Empty password verification succeeds")
      (ok (not (verify-password "notempty" hashed))
          "Non-empty password against empty hash fails")))

  (testing "不正なハッシュ形式での検証"
    (ok (null (verify-password "password" "invalid-hash-format"))
        "Invalid hash format returns NIL")
    (ok (null (verify-password "password" "notpbkdf2format"))
        "Non-PBKDF2 format returns NIL"))

  (testing "空文字ハッシュでの検証"
    (ok (null (verify-password "password" ""))
        "Empty hash returns NIL"))

  (testing "NILハッシュでの検証"
    ;; verify-passwordがNILを受け取った場合の挙動を検証
    ;; ironclad:pbkdf2-check-password が NIL を受け取るとエラーになるが、
    ;; handler-case で捕捉されて NIL が返る設計（src/util/crypto.lisp:34-41）
    (ok (null (verify-password "password" nil))
        "NIL hash returns NIL"))

  (testing "ハッシュにゴミデータが混入した場合"
    (let* ((valid-hash (hash-password "password"))
           (corrupted-hash (concatenate 'string valid-hash "garbage")))
      (ok (null (verify-password "password" corrupted-hash))
          "Corrupted hash returns NIL")))

  (testing "大文字小文字は区別される"
    (let ((hashed (hash-password "Password")))
      (ok (verify-password "Password" hashed)
          "Same case matches")
      (ok (not (verify-password "password" hashed))
          "Different case fails")
      (ok (not (verify-password "PASSWORD" hashed))
          "All uppercase fails")))

  (testing "先頭・末尾の空白は区別される"
    (let ((hashed (hash-password "password")))
      (ok (not (verify-password " password" hashed))
          "Leading space fails")
      (ok (not (verify-password "password " hashed))
          "Trailing space fails")
      (ok (not (verify-password " password " hashed))
          "Both spaces fail")))

  (testing "空白のみのパスワードは空文字と区別される"
    (let ((hashed-spaces (hash-password "   "))
          (hashed-empty (hash-password "")))
      (ok (verify-password "   " hashed-spaces)
          "Spaces-only password verifies correctly")
      (ok (not (verify-password "" hashed-spaces))
          "Empty password fails against spaces hash")
      (ok (verify-password "" hashed-empty)
          "Empty password verifies correctly")
      (ok (not (verify-password "   " hashed-empty))
          "Spaces-only fails against empty hash"))))

;;;
;;; エラー型の:reportラムダをテスト
;;; これらのテストは、エラーを文字列化して:reportラムダを実行させる
;;;
;;; 注: error-caught フラグでエラー発生を明示的に確認し、
;;;     エラーが発生しない場合のサイレントパスを防止
;;;

(deftest test-validation-error-report
  (testing "validation-errorの文字列表現"
    (let ((error-caught nil))
      (handler-case
          (validate-password "short")  ;; 必ずエラーを発生させる
        (validation-error (e)
          (setf error-caught t)
          ;; format "~A" が :report ラムダを呼び出す
          (let ((error-string (format nil "~A" e)))
            (ok (search "Validation error:" error-string)
                "Error string contains 'Validation error:'")
            (ok (search "8 characters" error-string)
                "Error string contains the specific message"))))
      (ok error-caught "validation-error should be signaled"))))

(deftest test-authorization-error-report
  (testing "authorization-errorの文字列表現"
    (let ((error-caught nil))
      (handler-case
          (error 'authorization-error :message "Not authorized")
        (authorization-error (e)
          (setf error-caught t)
          (let ((error-string (format nil "~A" e)))
            (ok (search "Authorization error:" error-string)
                "Error string contains 'Authorization error:'")
            (ok (search "Not authorized" error-string)
                "Error string contains the message"))))
      (ok error-caught "authorization-error should be signaled"))))

(deftest test-not-found-error-report
  (testing "not-found-errorの文字列表現"
    (let ((error-caught nil))
      (handler-case
          (error 'not-found-error :message "Resource not found")
        (not-found-error (e)
          (setf error-caught t)
          (let ((error-string (format nil "~A" e)))
            (ok (search "Not found:" error-string)
                "Error string contains 'Not found:'")
            (ok (search "Resource not found" error-string)
                "Error string contains the message"))))
      (ok error-caught "not-found-error should be signaled"))))

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

;;; JSON変換テスト（追加: Branch カバレッジ改善）

(deftest json-alist-string-key-test ()
  "文字列キーを持つalistのテスト"
  (testing "alist-to-hash-table-recursive で文字列キー"
    (let ((result (alist-to-hash-table-recursive
                    '(("name" . "test") ("value" . 123)))))
      (ok (hash-table-p result)
          "Result is a hash-table")
      (ok (equal "test" (gethash "name" result))
          "String key 'name' works")
      (ok (= 123 (gethash "value" result))
          "String key 'value' works")))

  (testing "ネストしたalistで文字列キー（値の変換）"
    (let ((result (alist-to-hash-table-recursive
                    '((:|outer| . (("inner" . "nested")))))))
      (ok (hash-table-p result))
      (let ((inner (gethash "outer" result)))
        (ok (hash-table-p inner)
            "Nested alist is converted to hash-table")
        (ok (equal "nested" (gethash "inner" inner))
            "String key in nested alist works")))))

(deftest json-alist-non-alist-input-test ()
  "alist以外の入力に対するテスト"
  (testing "単純なリスト（非alist）はvectorに変換"
    (let ((result (alist-to-hash-table-recursive '(1 2 3))))
      (ok (vectorp result)
          "Simple list is converted to vector")
      (ok (= 3 (length result))
          "Vector has correct length")
      (ok (= 1 (aref result 0))
          "First element is 1")
      (ok (= 2 (aref result 1))
          "Second element is 2")
      (ok (= 3 (aref result 2))
          "Third element is 3")))

  (testing "文字列のリストもvectorに変換"
    (let ((result (alist-to-hash-table-recursive '("a" "b" "c"))))
      (ok (vectorp result))
      (ok (equal "a" (aref result 0)))))

  (testing "混合リストもvectorに変換"
    (let ((result (alist-to-hash-table-recursive '(1 "two" :three))))
      (ok (vectorp result))
      (ok (= 3 (length result))))))

(deftest json-alist-primitive-input-test ()
  "プリミティブ値の入力に対するテスト"
  (testing "数値はそのまま返す"
    (ok (= 42 (alist-to-hash-table-recursive 42))
        "Integer is returned as-is")
    (ok (= 3.14 (alist-to-hash-table-recursive 3.14))
        "Float is returned as-is"))

  (testing "文字列はそのまま返す"
    (ok (equal "hello" (alist-to-hash-table-recursive "hello"))
        "String is returned as-is"))

  (testing "キーワードシンボルはそのまま返す"
    (ok (eq :keyword (alist-to-hash-table-recursive :keyword))
        "Keyword is returned as-is"))

  (testing "tはそのまま返す"
    (ok (eq t (alist-to-hash-table-recursive t))
        "T is returned as-is"))

  (testing "vectorはそのまま返す"
    (let ((input #(1 2 3)))
      (ok (eq input (alist-to-hash-table-recursive input))
          "Vector is returned as-is (not converted)"))))

(deftest json-alist-list-key-test ()
  "キーがリストの場合のテスト（alistとして扱われない）"
  (testing "キーがリストの場合はトップレベルでalistではない"
    (let ((result (alist-to-hash-table-recursive
                    '((((:key-list)) "value1" "value2")))))
      ;; トップレベルでは (caar data) = ((:key-list)) がリストなので
      ;; alist ではないと判定され、vector に変換される
      (ok (vectorp result)
          "Top-level is converted to vector (not alist)")
      (ok (= 1 (length result))
          "Vector has one element")
      ;; 要素 (((:key-list)) "value1" "value2") も (caar ...) がリストなので
      ;; alist ではないと判定され、vector に変換される
      (ok (vectorp (aref result 0))
          "Element is also converted to vector (nested list key)")))

  (testing "複数のリストキー要素を持つ場合"
    (let ((result (alist-to-hash-table-recursive
                    '((((:a)) 1) (((:b)) 2)))))
      (ok (vectorp result))
      (ok (= 2 (length result)))
      (ok (vectorp (aref result 0)))
      (ok (vectorp (aref result 1))))))

(deftest json-plist-string-key-test ()
  "文字列キーを持つplistのテスト"
  (testing "文字列キーのplist"
    (let ((result (plist-to-hash-table '("name" "test" "value" 123))))
      (ok (hash-table-p result)
          "Result is a hash-table")
      (ok (equal "test" (gethash "name" result))
          "String key 'name' works")
      (ok (= 123 (gethash "value" result))
          "String key 'value' works")))

  (testing "混合キー（シンボルと文字列）のplist"
    (let ((result (plist-to-hash-table '(:|symbol| "sym-value" "string" "str-value"))))
      (ok (hash-table-p result))
      (ok (equal "sym-value" (gethash "symbol" result))
          "Symbol key works")
      (ok (equal "str-value" (gethash "string" result))
          "String key works"))))

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
;;; get-body-param 追加テスト（test/util-test.lisp に追加）
;;;

(deftest test-get-body-param-edge-cases
  (testing "マルチバイト文字のキー"
    (let ((params '(("ユーザー名" . "テスト"))))
      (ok (equal "テスト" (get-body-param params "ユーザー名"))
          "Japanese key is found")))

  (testing "マルチバイト文字の値"
    (let ((params '(("name" . "田中太郎"))))
      (ok (equal "田中太郎" (get-body-param params "name"))
          "Japanese value is returned correctly")))

  (testing "特殊文字を含むキー"
    (let ((params '(("user-name" . "test")
                    ("email@key" . "value")
                    ("key with space" . "spaced"))))
      (ok (equal "test" (get-body-param params "user-name"))
          "Key with hyphen is found")
      (ok (equal "value" (get-body-param params "email@key"))
          "Key with @ is found")
      (ok (equal "spaced" (get-body-param params "key with space"))
          "Key with space is found")))

  (testing "空文字キーでの検索"
    (let ((params '(("" . "empty-key-value") ("normal" . "value"))))
      (ok (equal "empty-key-value" (get-body-param params ""))
          "Empty string key is found")))

  (testing "値がNILのエントリ"
    (let ((params '(("nullvalue" . nil))))
      (ok (null (get-body-param params "nullvalue"))
          "NIL value is returned as NIL")))

  (testing "値が空文字のエントリ"
    (let ((params '(("emptyvalue" . ""))))
      (ok (equal "" (get-body-param params "emptyvalue"))
          "Empty string value is returned")))

  (testing "重複キーがある場合（最初のものが返る）"
    (let ((params '(("dup" . "first") ("other" . "value") ("dup" . "second"))))
      (ok (equal "first" (get-body-param params "dup"))
          "First occurrence is returned for duplicate keys"))))

;;; get-query-param テスト

(deftest test-get-query-param
  (testing "存在するパラメータを取得"
    (let ((params '(("page" . "1") ("per_page" . "20"))))
      (ok (string= (get-query-param params "page") "1"))
      (ok (string= (get-query-param params "per_page") "20"))))

  (testing "存在しないパラメータはNIL"
    (ok (null (get-query-param '() "page"))))

  (testing "デフォルト値を返す"
    (ok (string= (get-query-param '() "page" "1") "1"))
    (ok (string= (get-query-param '(("other" . "value")) "page" "1") "1")))

  (testing "パラメータが存在する場合はデフォルト値を無視"
    (let ((params '(("page" . "5"))))
      (ok (string= (get-query-param params "page" "1") "5"))))

  (testing "キーの比較は文字列比較（string=）"
    (let ((params '(("Page" . "1"))))
      (ok (null (get-query-param params "page")))
      (ok (string= (get-query-param params "Page") "1")))))

;;; parse-integer-param テスト

(deftest test-parse-integer-param
  (testing "正常な整数文字列"
    (ok (= (parse-integer-param "42") 42))
    (ok (= (parse-integer-param "0") 0))
    (ok (= (parse-integer-param "-10") -10)))

  (testing "不正な文字列はデフォルト値"
    (ok (= (parse-integer-param "invalid" 1) 1))
    (ok (= (parse-integer-param "12.5" 1) 1))
    (ok (= (parse-integer-param "" 1) 1)))

  (testing "NILはデフォルト値"
    (ok (= (parse-integer-param nil 1) 1)))

  (testing "デフォルト未指定でNIL"
    (ok (null (parse-integer-param nil)))
    (ok (null (parse-integer-param "invalid")))))

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
