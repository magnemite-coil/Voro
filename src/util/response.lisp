(defpackage voro.util.response
  (:use :cl)
  (:export
   :response-success
   :response-error
   :json-response))

(in-package :voro.util.response)

(defun json-response (status-code body)
  "JSON レスポンスを生成"
  (list status-code
        (list :content-type "application/json; charset=utf-8")
        (list (jonathan:to-json body :from :alist))))

(defun response-success (data &key (status 200))
  "成功レスポンスを生成
   data: alist形式のデータ (例: (list :|user| user-data))"
  (json-response status
                 (list (cons :|success| t)
                       (cons :|data| data))))

(defun response-error (status message &key error-id)
  "エラーレスポンスを生成
   status: HTTPステータスコード
   message: ユーザー向けエラーメッセージ
   error-id: エラー追跡用ID（オプション）"
  (let ((error-data (list (cons :|success| :false)
                          (cons :|error| message))))
    (when error-id
      (setf error-data (append error-data
                               (list (cons :|error_id| error-id)))))
    (json-response status error-data)))
