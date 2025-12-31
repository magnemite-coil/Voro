(defpackage voro.util.request
  (:use :cl)
  (:export
   :get-body-param
   :get-query-param
   :parse-integer-param))

(in-package :voro.util.request)

;;; リクエストボディ操作

(defun get-body-param (body-parameters key)
  "リクエストボディからパラメータを取得

   body-parameters: パラメータの連想リスト（alist）
   key: パラメータ名（文字列）

   戻り値: パラメータの値、存在しない場合はNIL

   使用例:
   (get-body-param '((\"username\" . \"test\") (\"email\" . \"test@example.com\")) \"username\")
   => \"test\""
  (cdr (assoc key body-parameters :test #'string=)))

;;; クエリパラメータ操作

(defun get-query-param (query-parameters key &optional default)
  "クエリパラメータを取得

   query-parameters: クエリパラメータの連想リスト（alist）
   key: パラメータ名（文字列）
   default: パラメータが存在しない場合のデフォルト値（オプション）

   戻り値: パラメータの値、存在しない場合はDEFAULT

   使用例:
   (get-query-param '((\"page\" . \"1\") (\"per_page\" . \"20\")) \"page\")
   => \"1\"
   (get-query-param '() \"page\" \"1\")
   => \"1\""
  (or (cdr (assoc key query-parameters :test #'string=))
      default))

;;; パラメータ変換

(defun parse-integer-param (value &optional default)
  "文字列パラメータを整数に変換

   value: 変換対象の文字列（NIL可）
   default: 変換失敗時またはNIL時のデフォルト値

   戻り値: 整数値、変換失敗時はDEFAULT

   使用例:
   (parse-integer-param \"42\")
   => 42
   (parse-integer-param \"invalid\" 1)
   => 1
   (parse-integer-param nil 1)
   => 1"
  (if value
      (handler-case (parse-integer value)
        (error () default))
      default))
