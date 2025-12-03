(defpackage voro.util.request
  (:use :cl)
  (:export
   :get-body-param))

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
