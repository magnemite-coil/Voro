(defpackage voro.test.direct-call-helper
  (:use :cl :rove)
  (:import-from :voro.web
                :*app*)
  (:import-from :lack.component
                :call)  ;; Lackコンポーネント呼び出し用
  (:import-from :voro.test.http-helper
                :alist-to-hash-table)  ;; 既存関数を再利用
  (:import-from :flexi-streams
                :make-in-memory-input-stream
                :string-to-octets
                :octets-to-string)
  (:local-nicknames (:jzon :com.inuoe.jzon)
                    (:ppcre :cl-ppcre))
  (:export
   ;; 環境構築
   :make-test-env

   ;; リクエストヘルパー
   :direct-get
   :direct-post
   :direct-put
   :direct-delete

   ;; レスポンス検証
   :assert-direct-status
   :assert-direct-json
   :assert-direct-json-value
   :assert-direct-cookie

   ;; セッションヘルパー
   :extract-session-id))

(in-package :voro.test.direct-call-helper)

;;;
;;; Lack環境構築
;;;
;;; 参考: Lack仕様 (https://github.com/fukamachi/lack)
;;; 必須キー: :request-method, :script-name, :path-info, :request-uri,
;;;          :server-name, :server-port, :server-protocol, :url-scheme,
;;;          :remote-addr, :remote-port, :headers
;;; 任意キー: :query-string, :content-type, :content-length, :raw-body
;;;

(defun make-test-env (method path &key json cookies query-string)
  "テスト用Lack環境（env）を構築

   method: HTTPメソッド（:GET, :POST, :PUT, :DELETE）
   path: リクエストパス（例: \"/api/auth/register\"）
   json: リクエストボディ
         - hash-table: そのまま使用
         - alist: キーワードシンボルキーのみ対応（例: '((:|username| . \"user\"))）
                  ※ 文字列キーのalistはエラー（alist-to-hash-tableがsymbol-name前提）
   cookies: Cookie連想リスト（例: '((\"session_id\" . \"xxx\"))）
   query-string: クエリ文字列（例: \"page=1&per_page=20\"）

   戻り値: Lack環境（plist）

   注意:
   - :headers はhash-table形式（Lack仕様）
   - :request-uri は完全なリクエストURI（path + query-string）
   - JSONボディはhttp-bodyミドルウェアがパースし、alist形式（文字列キー）で返す
   - Acceptヘッダーは自動設定される（Dexador互換、lack.request解析エラー回避）"
  (let* ((body-hash (when json
                      (if (hash-table-p json)
                          json
                          (alist-to-hash-table json))))
         (body-string (when body-hash (jzon:stringify body-hash)))
         (body-octets (when body-string (string-to-octets body-string :external-format :utf-8)))
         (body-stream (when body-octets (make-in-memory-input-stream body-octets)))
         ;; Lack仕様: :request-uri は完全なURI（スキーム後）
         (request-uri (if query-string
                          (format nil "~A?~A" path query-string)
                          path))
         ;; Lack仕様: :headers はhash-table形式
         (headers (make-hash-table :test 'equal)))

    ;; Content-Typeヘッダーを設定
    (when json
      (setf (gethash "content-type" headers) "application/json"))

    ;; Acceptヘッダーを設定（Dexador互換）
    ;; Dexadorは自動でAcceptを付与するが、直接呼び出しでは必須
    ;; lack.requestのrequest-accept解析でnilを回避
    (setf (gethash "accept" headers) "application/json, */*")

    ;; Cookieヘッダーを設定
    (when cookies
      (setf (gethash "cookie" headers) (format-cookie-header cookies)))

    (list :request-method method              ;; Lack仕様: :GET, :POST等（大文字）
          :script-name ""
          :path-info path
          :query-string (or query-string "")
          :request-uri request-uri              ;; Lack仕様: 必須
          :server-name "localhost"
          :server-port 8080
          :server-protocol :HTTP/1.1            ;; Lack仕様: 大文字
          :url-scheme "http"
          :remote-addr "127.0.0.1"
          :remote-port 12345
          :headers headers                      ;; Lack仕様: 必須（hash-table）
          :content-type (when json "application/json")
          :content-length (when body-octets (length body-octets))
          :raw-body body-stream
          :clack.streaming nil)))

(defun format-cookie-header (cookies)
  "Cookie連想リストをHTTP Cookie形式に変換"
  (when cookies
    (format nil "~{~A=~A~^; ~}"
            (loop for (name . value) in cookies
                  collect name
                  collect value))))

;;;
;;; リクエストヘルパー
;;;

(defun call-app (env)
  "Lackアプリケーションを直接呼び出す

   戻り値: (status headers body-list)

   注意:
   - *app* はLackコンポーネントであり、直接funcallできない
   - lack.component:call を使用してコンポーネントを呼び出す
   - アプリケーション内部で発生したエラーは呼び出し元に伝播する
   - Handlerのhandler-caseで捕捉されないエラーはここで発生する
   - テスト側でエラーケースを検証する場合は、handler-caseでラップすること

   例:
   (handler-case
       (call-app env)
     (error (e)
       ;; エラーケースの検証
       (ok (typep e 'error))))"
  ;; lack.component:call を使用（*app* は Lack component であり直接 funcall 不可）
  ;; 参照: test/web-test.lisp:25 - (lack.component:to-app *app*) の検証
  (call *app* env))

(defun direct-get (path &key cookies query-string)
  "GETリクエストを直接実行

   戻り値: (values body status headers)"
  (let* ((env (make-test-env :GET path      ;; Lack仕様: 大文字
                             :cookies cookies
                             :query-string query-string))
         (response (call-app env)))
    (parse-response response)))

(defun direct-post (path &key json cookies)
  "POSTリクエストを直接実行

   戻り値: (values body status headers)"
  (let* ((env (make-test-env :POST path     ;; Lack仕様: 大文字
                             :json json
                             :cookies cookies))
         (response (call-app env)))
    (parse-response response)))

(defun direct-put (path &key json cookies)
  "PUTリクエストを直接実行

   戻り値: (values body status headers)"
  (let* ((env (make-test-env :PUT path      ;; Lack仕様: 大文字
                             :json json
                             :cookies cookies))
         (response (call-app env)))
    (parse-response response)))

(defun direct-delete (path &key cookies)
  "DELETEリクエストを直接実行

   戻り値: (values body status headers)"
  (let* ((env (make-test-env :DELETE path   ;; Lack仕様: 大文字
                             :cookies cookies))
         (response (call-app env)))
    (parse-response response)))

;;;
;;; レスポンス解析
;;;

(defun parse-response (response)
  "Lackレスポンスを解析

   response: (status headers body-list)

   戻り値: (values body-string status headers-alist)"
  (destructuring-bind (status headers body-list) response
    (let ((body-string (extract-body-string body-list)))
      (values body-string status (plist-to-alist headers)))))

(defun extract-body-string (body-list)
  "ボディリストから文字列を抽出

   対応形式:
   - nil → 空文字列
   - 文字列 → そのまま返す
   - 文字列のリスト → 連結して返す
   - バイトベクタ (vector (unsigned-byte 8)) → UTF-8でデコード

   注意: パス名（ファイル参照）には未対応（JSON API用途を想定）"
  (cond
    ((null body-list) "")
    ((stringp body-list) body-list)
    ((and (typep body-list '(vector (unsigned-byte 8))))
     ;; バイトベクタの場合はUTF-8でデコード
     (octets-to-string body-list :external-format :utf-8))
    ((listp body-list)
     (with-output-to-string (s)
       (dolist (chunk body-list)
         (cond
           ((stringp chunk)
            (write-string chunk s))
           ((typep chunk '(vector (unsigned-byte 8)))
            (write-string (octets-to-string chunk :external-format :utf-8) s))))))
    (t (princ-to-string body-list))))

(defun plist-to-alist (plist)
  "plist形式のヘッダーをalist形式に変換"
  (loop for (key value) on plist by #'cddr
        collect (cons (string-downcase (symbol-name key)) value)))

;;;
;;; レスポンス検証
;;;

(defun assert-direct-status (expected-status actual-status)
  "ステータスコードを検証"
  (ok (= expected-status actual-status)
      (format nil "Expected status ~D, got ~D" expected-status actual-status)))

(defun assert-direct-json (body &rest keys)
  "JSONレスポンスボディを検証（キーパスが存在することを確認）"
  (let* ((parsed (jzon:parse body))
         (result (reduce (lambda (obj key)
                          (when obj
                            (gethash (string-downcase (string key)) obj)))
                        keys
                        :initial-value parsed)))
    (ok (not (null result))
        (format nil "Key path ~{~A~^.~} exists in JSON response" keys))))

(defun assert-direct-json-value (expected body &rest keys)
  "JSONレスポンスの特定キーの値を検証"
  (let* ((parsed (jzon:parse body))
         (actual (reduce (lambda (obj key)
                          (when obj
                            (gethash (string-downcase (string key)) obj)))
                        keys
                        :initial-value parsed)))
    (ok (equal expected actual)
        (format nil "Expected ~A at ~{~A~^.~}, got ~A"
                expected keys actual))))

(defun assert-direct-cookie (name headers)
  "Set-CookieヘッダーでCookieが設定されているか検証"
  (let ((set-cookie (cdr (assoc "set-cookie" headers :test #'string=))))
    (ok (and set-cookie (search name set-cookie))
        (format nil "Cookie '~A' is set" name))))

;;;
;;; セッションヘルパー
;;;
;;; 注意: http-helper.lisp には extract-session-cookie 関数が存在するが、
;;;       headersの形式が異なるため別関数として定義する。
;;;
;;;   - extract-session-cookie (http-helper.lisp):
;;;       headers が hash-table 形式（Dexadorのレスポンス）
;;;       (gethash "set-cookie" headers) でアクセス
;;;
;;;   - extract-session-id (direct-call-helper.lisp):
;;;       headers が alist 形式（plist-to-alist変換後のLackレスポンス）
;;;       (assoc "set-cookie" headers) でアクセス
;;;

(defun extract-session-id (headers)
  "headersのalist形式からセッションIDを抽出

   headers: plist-to-alistで変換されたヘッダー（alist形式）
            ※ http-helper.lisp の extract-session-cookie とは異なり、
              hash-tableではなくalistを受け取る
   戻り値: セッションID文字列、またはNIL"
  (let ((set-cookie (cdr (assoc "set-cookie" headers :test #'string=))))
    (when set-cookie
      (ppcre:register-groups-bind (session-id)
          ("session_id=([^;]+)" set-cookie)
        session-id))))
