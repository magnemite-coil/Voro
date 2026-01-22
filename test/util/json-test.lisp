;;; test/util/json-test.lisp
;;;
;;; util/json.lisp のテスト
;;; JSON変換関数のカバレッジを拡充
;;;

(defpackage voro.test.util.json
  (:use :cl :rove)
  (:local-nicknames (:jzon :com.inuoe.jzon))  ;; Jzonエラー条件用
  (:import-from :voro.util.json
                :to-json
                :to-json-plist
                :parse-json
                :alist-to-hash-table-recursive
                :plist-to-hash-table))

(in-package :voro.test.util.json)

;;;
;;; to-json テスト
;;;

(deftest test-to-json
  (testing "単純なalist"
    (ok (string= (to-json '((:|name| . "test"))) "{\"name\":\"test\"}")
        "Simple alist converts to JSON"))

  (testing "ネストしたalist"
    (ok (string= (to-json '((:|user| . ((:|id| . 1)))))
                 "{\"user\":{\"id\":1}}")
        "Nested alist converts correctly"))

  (testing "リスト値"
    (ok (string= (to-json '((:|items| . (1 2 3))))
                 "{\"items\":[1,2,3]}")
        "List values become JSON arrays"))

  (testing "boolean: t"
    (ok (string= (to-json '((:|enabled| . t)))
                 "{\"enabled\":true}")
        "t converts to true"))

  (testing "boolean: nil"
    (ok (string= (to-json '((:|disabled| . nil)))
                 "{\"disabled\":false}")
        "nil converts to false"))

  (testing "空alist"
    (ok (string= (to-json nil) "{}")
        "Empty alist converts to empty object")))

(deftest test-to-json-special-chars
  (testing "日本語値"
    ;; 複数キーや順序依存を避けるため、parse-json 後に値比較
    (let* ((json-str (to-json '((:|name| . "田中"))))
           (parsed (parse-json json-str)))
      (ok (equal (gethash "name" parsed) "田中")
          "Japanese characters preserved")))

  (testing "特殊文字（ダブルクォート、バックスラッシュ）"
    (let* ((json-str (to-json '((:|text| . "a\"b\\c"))))
           (parsed (parse-json json-str)))
      (ok (equal (gethash "text" parsed) "a\"b\\c")
          "Special characters escaped and preserved")))

  (testing "改行文字"
    (let* ((json-str (to-json '((:|text| . "line1
line2"))))
           (parsed (parse-json json-str)))
      (ok (equal (gethash "text" parsed) "line1
line2")
          "Newlines preserved"))))

(deftest test-to-json-deep-nesting
  (testing "5段ネストのalist"
    ;; 入力: 5段のネスト構造
    (let* ((data '((:|l1| . ((:|l2| . ((:|l3| . ((:|l4| . ((:|l5| . "deep")))))))))))
           (json-str (to-json data))
           (parsed (parse-json json-str)))
      ;; parse-json 後に値比較（キー順序に依存しない検証）
      (ok (hash-table-p parsed) "Top level is hash-table")
      (let* ((l1 (gethash "l1" parsed))
             (l2 (gethash "l2" l1))
             (l3 (gethash "l3" l2))
             (l4 (gethash "l4" l3))
             (l5 (gethash "l5" l4)))
        (ok (equal "deep" l5) "Deeply nested value is preserved"))))

  (testing "ネスト + 配列の組み合わせ"
    ;; 複合構造: オブジェクト内に配列、配列内にオブジェクト
    (let* ((data '((:|users| . (((:|id| . 1) (:|name| . "Alice"))
                                ((:|id| . 2) (:|name| . "Bob"))))))
           (json-str (to-json data))
           (parsed (parse-json json-str)))
      (let ((users (gethash "users" parsed)))
        (ok (vectorp users) "users is array")
        (ok (= (length users) 2) "Array has 2 elements")
        (ok (equal "Alice" (gethash "name" (aref users 0))) "First user is Alice")))))

(deftest test-to-json-large-data
  (testing "100要素以上のリスト"
    (let* ((items (loop for i from 1 to 100 collect i))
           (data `((:|items| . ,items)))
           (json-str (to-json data))
           (parsed (parse-json json-str)))
      (ok (vectorp (gethash "items" parsed)) "Large list is array")
      (ok (= (length (gethash "items" parsed)) 100) "Array has 100 elements"))))

;;;
;;; to-json-plist テスト
;;;

(deftest test-to-json-plist
  (testing "単純なplist"
    (ok (string= (to-json-plist '(:|name| "test"))
                 "{\"name\":\"test\"}")
        "Simple plist converts to JSON"))

  (testing "複数キーのplist"
    ;; キー順序に依存しない検証
    (let* ((json-str (to-json-plist '(:|a| 1 :|b| 2)))
           (parsed (parse-json json-str)))
      (ok (= (gethash "a" parsed) 1) "a is 1")
      (ok (= (gethash "b" parsed) 2) "b is 2")))

  (testing "空plist"
    (ok (string= (to-json-plist nil) "{}")
        "Empty plist converts to empty object")))

;;;
;;; parse-json テスト
;;;

(deftest test-parse-json
  (testing "オブジェクト"
    (let ((result (parse-json "{\"name\":\"test\"}")))
      (ok (hash-table-p result) "Object parses to hash-table")
      (ok (equal (gethash "name" result) "test") "Value is correct")))

  (testing "配列"
    (let ((result (parse-json "[1,2,3]")))
      (ok (vectorp result) "Array parses to vector")
      (ok (= (length result) 3) "Length is 3")))

  (testing "true"
    (ok (eq (parse-json "true") t) "true parses to t"))

  (testing "false"
    (ok (eq (parse-json "false") nil) "false parses to nil"))

  (testing "null"
    (ok (eq (parse-json "null") 'null) "null parses to 'null (Jzon仕様)"))

  (testing "数値"
    (ok (= (parse-json "42") 42) "Number parses correctly")))

(deftest test-parse-json-errors
  ;; 推奨: 親クラス jzon:json-error での検証
  ;; ライブラリ更新に強い、安定したテスト
  (testing "不正なJSON構文（推奨: 親クラス検証）"
    (ok (signals (parse-json "invalid") 'jzon:json-error)
        "Invalid JSON signals json-error"))

  (testing "空文字列"
    ;; 注: Jzonは空文字列に対して TYPE-ERROR を発生させる（json-error ではない）
    ;; より広い error クラスで検証することで、ライブラリ更新に耐性を持たせる
    (ok (signals (parse-json "") 'error)
        "Empty string signals error"))

  (testing "閉じ括弧なし（推奨: 親クラス検証）"
    (ok (signals (parse-json "{\"a\": 1") 'jzon:json-error)
        "Unclosed brace signals json-error"))

  ;; === 任意: 詳細クラスでの検証（コメントアウト例） ===
  ;; より詳細なエラー種別を確認したい場合は以下を有効化
  ;; 注意: ライブラリ更新で壊れる可能性があるため、デフォルトでは無効
  ;; 有効化手順: 以下のコメントを解除して実行
  #|
  (testing "詳細クラス検証（任意・デフォルト無効）"
    ;; エラー階層: json-eof-error → json-parse-error → json-error
    (ok (signals (parse-json "invalid") 'jzon:json-parse-error)
        "Invalid JSON signals json-parse-error (詳細)")
    (ok (signals (parse-json "") 'jzon:json-eof-error)
        "Empty string signals json-eof-error (詳細)")
    (ok (signals (parse-json "{\"a\": 1") 'jzon:json-eof-error)
        "Unclosed brace signals json-eof-error (詳細)"))
  |#
  )  ;; deftest 終端

;;;
;;; alist-to-hash-table-recursive テスト
;;;

(deftest test-alist-to-hash-table-recursive
  (testing "単純alist"
    (let ((ht (alist-to-hash-table-recursive '((:|a| . 1)))))
      (ok (hash-table-p ht) "Result is hash-table")
      (ok (= (gethash "a" ht) 1) "Value is correct")))

  (testing "シンボルキー（小文字化）"
    (let ((ht (alist-to-hash-table-recursive '((:KEY . "val")))))
      (ok (equal (gethash "key" ht) "val") "Symbol key lowercased")))

  (testing "文字列キー（そのまま）"
    (let ((ht (alist-to-hash-table-recursive '(("Key" . "val")))))
      (ok (equal (gethash "Key" ht) "val") "String key preserved")))

  (testing "深いネスト（3段）"
    (let ((ht (alist-to-hash-table-recursive
               '((:|a| . ((:|b| . ((:|c| . "deep")))))))))
      (ok (hash-table-p ht) "Top is hash-table")
      (let* ((a (gethash "a" ht))
             (b (gethash "b" a))
             (c (gethash "c" b)))
        (ok (equal c "deep") "Nested value accessible"))))

  (testing "非alist（リスト）"
    (let ((result (alist-to-hash-table-recursive '(1 2 3))))
      (ok (vectorp result) "List becomes vector")
      (ok (= (length result) 3) "Length is 3")))

  (testing "プリミティブ"
    (ok (= (alist-to-hash-table-recursive 42) 42) "Primitive unchanged"))

  (testing "nil → 空hash-table"
    (let ((ht (alist-to-hash-table-recursive nil)))
      (ok (hash-table-p ht) "nil becomes hash-table")
      (ok (= (hash-table-count ht) 0) "Hash-table is empty"))))

;;;
;;; plist-to-hash-table テスト
;;;

(deftest test-plist-to-hash-table
  (testing "通常plist"
    (let ((ht (plist-to-hash-table '(:|a| 1 :|b| 2))))
      (ok (hash-table-p ht) "Result is hash-table")
      (ok (= (gethash "a" ht) 1) "a is 1")
      (ok (= (gethash "b" ht) 2) "b is 2")))

  (testing "空plist"
    (let ((ht (plist-to-hash-table nil)))
      (ok (hash-table-p ht) "nil becomes hash-table")
      (ok (= (hash-table-count ht) 0) "Hash-table is empty")))

  (testing "奇数要素plist（最後のキーの値はnil）"
    ;; 現行仕様: 奇数要素の場合、最後のキーの値は nil
    ;; Jzonは nil を false に変換するため、JSON化時は "b": false となる
    ;; 呼び出し元が正しいplistを渡す責任を持つ設計
    (let ((ht (plist-to-hash-table '(:|a| 1 :|b|))))
      (ok (hash-table-p ht) "Result is hash-table")
      (ok (= (gethash "a" ht) 1) "a is 1")
      ;; multiple-value-bind で存在確認（val が nil の場合にキー不在と区別）
      (multiple-value-bind (val present-p) (gethash "b" ht)
        (ok present-p "b key exists")
        (ok (null val) "b value is nil")))))
