(defpackage voro.util.json
  (:use :cl)
  (:local-nicknames (:jzon :com.inuoe.jzon))
  (:export
   :to-json
   :to-json-plist
   :parse-json
   :alist-to-hash-table-recursive
   :plist-to-hash-table))

(in-package :voro.util.json)

(defun alist-value-to-jzon (value)
  "alistの値をJzon用に変換する
   - nil: そのまま（Jzonがfalseに変換）
   - alist: hash-tableに再帰変換
   - list: 各要素を再帰変換してvectorに
   - その他: そのまま返す"
  (cond
    ;; nilはそのまま（Jzonがfalseに変換する）
    ((null value) nil)
    ;; alistの判定: 非空リストで最初の要素がconsセル
    ((and (consp value)
          (consp (car value))
          (atom (caar value)))
     (let ((ht (make-hash-table :test 'equal)))
       (loop for (key . val) in value
             do (setf (gethash (if (symbolp key)
                                   (string-downcase (symbol-name key))
                                   key)
                               ht)
                      (alist-value-to-jzon val)))
       ht))
    ;; リスト（alistではない）: 各要素を再帰変換してvectorに
    ((listp value)
     (map 'vector #'alist-value-to-jzon value))
    ;; その他: そのまま
    (t value)))

(defun alist-to-hash-table-recursive (data)
  "alistをhash-tableに再帰的に変換する
   - トップレベルのnil: 空のhash-table（JSONの{}に対応）
   - alist: hash-tableに変換（値のnilはfalseとして扱う）
   - list/vector: 各要素を再帰的に変換してvectorに
   - その他: そのまま返す"
  (cond
    ;; トップレベルの空リストは空オブジェクトとして扱う
    ((null data) (make-hash-table :test 'equal))
    ;; alistの判定: 非空リストで最初の要素がconsセル
    ((and (consp data)
          (consp (car data))
          (atom (caar data)))
     (let ((ht (make-hash-table :test 'equal)))
       (loop for (key . value) in data
             do (setf (gethash (if (symbolp key)
                                   (string-downcase (symbol-name key))
                                   key)
                               ht)
                      (alist-value-to-jzon value)))
       ht))
    ;; リスト（alistではない）: 各要素を再帰変換してvectorに
    ((listp data)
     (map 'vector #'alist-value-to-jzon data))
    ;; その他: そのまま
    (t data)))

(defun plist-to-hash-table (plist)
  "plistをhash-tableに変換する"
  (if (null plist)
      (make-hash-table :test 'equal)
      (let ((ht (make-hash-table :test 'equal)))
        (loop for (key value) on plist by #'cddr
              do (setf (gethash (if (symbolp key)
                                    (string-downcase (symbol-name key))
                                    key)
                                ht)
                       value))
        ht)))

(defun to-json (data)
  "alist形式のデータをJSONに変換する"
  (jzon:stringify (alist-to-hash-table-recursive data)))

(defun to-json-plist (data)
  "plist形式のデータをJSONに変換する"
  (jzon:stringify (plist-to-hash-table data)))

(defun parse-json (string)
  "JSON文字列をパースする"
  (jzon:parse string))
