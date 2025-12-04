(defpackage voro.util.response
  (:use :cl)
  (:import-from :voro.util.json
                :to-json)
  (:export
   :response-success
   :response-error
   :json-response))

(in-package :voro.util.response)

(defun json-response (status-code body &key additional-headers)
  "JSON レスポンスを生成
   additional-headers: 追加ヘッダー (plist形式)"
  (list status-code
        (append (list :content-type "application/json; charset=utf-8")
                additional-headers)
        (list (to-json body))))

(defun response-success (data &key (status 200) headers)
  "成功レスポンスを生成
   data: alist形式のデータ (例: (list :|user| user-data))
         nilの場合は空オブジェクト {} として出力
   headers: 追加ヘッダー (plist形式)"
  (json-response status
                 (list (cons :|success| t)
                       (cons :|data| (or data (make-hash-table :test 'equal))))
                 :additional-headers headers))

(defun response-error (status message &key error-id headers)
  "エラーレスポンスを生成
   status: HTTPステータスコード
   message: ユーザー向けエラーメッセージ
   error-id: エラー追跡用ID（オプション）
   headers: 追加ヘッダー (plist形式)"
  (let ((error-data (list (cons :|success| nil)
                          (cons :|error| message))))
    (when error-id
      (setf error-data (append error-data
                               (list (cons :|error_id| error-id)))))
    (json-response status error-data :additional-headers headers)))
