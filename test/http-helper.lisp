(defpackage voro.test.http-helper
  (:use :cl :rove)
  (:import-from :clack
                :clackup
                :stop)
  (:import-from :dexador)
  (:local-nicknames (:jzon :com.inuoe.jzon))
  (:export
   ;; HTTPサーバー管理
   :with-test-server
   :start-test-server
   :stop-test-server
   :wait-for-server-ready
   :*test-server-port*
   :*test-server-base-url*

   ;; HTTPリクエストヘルパー
   :http-get
   :http-post
   :http-put
   :http-delete

   ;; レスポンス検証
   :assert-status
   :assert-json-response
   :assert-cookie

   ;; 認証ヘルパー
   :with-authenticated-user))

(in-package :voro.test.http-helper)

;;;
;;; テストサーバー設定
;;;

(defparameter *test-server-port* 18080
  "テスト用HTTPサーバーのポート番号（本番と重複しない）")

(defparameter *test-server-base-url*
  (format nil "http://localhost:~D" *test-server-port*)
  "テスト用HTTPサーバーのベースURL")

(defparameter *test-server-handler* nil
  "テストサーバーのハンドラー（停止時に使用）")

;;;
;;; HTTPサーバー管理
;;;

(defun start-test-server ()
  "テスト用HTTPサーバーを起動"
  ;; 既にサーバーが起動している場合は停止
  (when *test-server-handler*
    (stop-test-server))

  ;; voroパッケージをロードしてアプリケーションを確実に初期化
  (unless (find-package :voro.web)
    (error "voro.web package not loaded"))

  (let ((app-symbol (find-symbol "*APP*" :voro.web)))
    (unless app-symbol
      (error "*APP* symbol not found in voro.web package"))

    (let ((app (symbol-value app-symbol)))
      (unless app
        (error "*APP* is not initialized"))

      (setf *test-server-handler*
            (clack:clackup app
                          :server :woo
                          :port *test-server-port*
                          :worker-num 1  ;; モックテスト用: シングルワーカを明示
                          :use-default-middlewares nil
                          :debug nil
                          :silent t)))))

(defun stop-test-server ()
  "テスト用HTTPサーバーを停止"
  (when *test-server-handler*
    (clack:stop *test-server-handler*)
    (setf *test-server-handler* nil)))

(defun wait-for-server-ready (&optional (max-retries 20))
  "HTTPサーバーが起動するまで待機（ヘルスチェック）

  引数:
    max-retries: 最大リトライ回数（デフォルト: 20回、合計10秒）

  戻り値: サーバー起動成功時にT、タイムアウト時にエラー

  注: ルートパス (/) が未定義のアプリケーションでも動作するよう、
      404レスポンスも正常なヘルスチェック結果として扱う
      (Phase0 PoCで検証済み: 2025-11-24)"
  (loop repeat max-retries
        do (handler-case
               (multiple-value-bind (body status)
                   (dex:get (format nil "~A/" *test-server-base-url*)
                            :connect-timeout 1)
                 (declare (ignore body))
                 ;; サーバーが応答していれば成功（200でも404でも可）
                 (when (or (= status 200) (= status 404))
                   (return t)))
             (dex:http-request-not-found ()
               ;; 404エラーはサーバーが起動している証拠
               (return t))
             (error ()
               ;; 接続エラーなどはリトライ
               (sleep 0.5)))
        finally (error "Test server failed to start after ~D retries (~D seconds)"
                       max-retries
                       (* max-retries 0.5))))

(defmacro with-test-server (&body body)
  "テスト用HTTPサーバーを起動してテストを実行

  使用例:
    (deftest auth-register-test ()
      (with-test-server
        (with-test-db
          (let ((response (http-post \"/api/auth/register\"
                                     :json '((:|username| . \"testuser\")
                                             (:|password| . \"password123\")))))
            (assert-status 200 response)
            (assert-json-response response '(\"user\" \"id\"))))))"

  `(unwind-protect
        (progn
          (start-test-server)
          (wait-for-server-ready)  ; ヘルスチェック
          ,@body)
     (stop-test-server)))

;;;
;;; HTTPリクエストヘルパー
;;;

(defun alist-to-hash-table (alist)
  "Alist形式のデータをハッシュテーブルに変換（Jzon用）

  Jzonはalistを直接サポートしないため、
  ハッシュテーブルに変換してからJSONエンコードする。

  例: '((:|username| . \"user\") (:|password| . \"pass\"))
      => #<HASH-TABLE :TEST EQUAL \"username\" \"user\" \"password\" \"pass\">"
  (let ((hash-table (make-hash-table :test 'equal)))
    (loop for (key . value) in alist
          do (setf (gethash (string-downcase (symbol-name key)) hash-table)
                   value))
    hash-table))

(defun http-get (path &key headers cookies)
  "HTTPGETリクエストを送信

  戻り値: (values body status headers)"
  (handler-case
      (multiple-value-bind (body status response-headers)
          (dex:get (format nil "~A~A" *test-server-base-url* path)
                   :headers (append headers (make-cookie-header cookies)))
        (values body status response-headers))
    (dex:http-request-failed (e)
      (values (dex:response-body e)
              (dex:response-status e)
              (dex:response-headers e)))))

(defun http-post (path &key json headers cookies)
  "HTTP POSTリクエストを送信

  引数:
    json: Alist形式のJSONデータ（キーワードシンボル使用）
          例: '((:|username| . \"user\") (:|password| . \"pass\"))

  戻り値: (values body status headers)"
  (handler-case
      (multiple-value-bind (body status response-headers)
          (dex:post (format nil "~A~A" *test-server-base-url* path)
                    :content (when json
                              (jzon:stringify (alist-to-hash-table json)))
                    :headers (append '(("Content-Type" . "application/json"))
                                   headers
                                   (make-cookie-header cookies)))
        (values body status response-headers))
    (dex:http-request-failed (e)
      ;; HTTPエラー(400, 401, etc)をキャッチして、ステータスとボディを返す
      (values (dex:response-body e)
              (dex:response-status e)
              (dex:response-headers e)))))

(defun http-put (path &key json headers cookies)
  "HTTP PUTリクエストを送信

  引数:
    json: Alist形式のJSONデータ（キーワードシンボル使用）
          例: '((:|username| . \"user\") (:|password| . \"pass\"))

  戻り値: (values body status headers)"
  (handler-case
      (multiple-value-bind (body status response-headers)
          (dex:put (format nil "~A~A" *test-server-base-url* path)
                   :content (when json
                             (jzon:stringify (alist-to-hash-table json)))
                   :headers (append '(("Content-Type" . "application/json"))
                                  headers
                                  (make-cookie-header cookies)))
        (values body status response-headers))
    (dex:http-request-failed (e)
      (values (dex:response-body e)
              (dex:response-status e)
              (dex:response-headers e)))))

(defun http-delete (path &key headers cookies)
  "HTTP DELETEリクエストを送信

  戻り値: (values body status headers)"
  (handler-case
      (multiple-value-bind (body status response-headers)
          (dex:delete (format nil "~A~A" *test-server-base-url* path)
                      :headers (append headers (make-cookie-header cookies)))
        (values body status response-headers))
    (dex:http-request-failed (e)
      (values (dex:response-body e)
              (dex:response-status e)
              (dex:response-headers e)))))

;;;
;;; Cookie管理
;;;

(defun make-cookie-header (cookies)
  "CookieリストからCookieヘッダーを作成"
  (when cookies
    (list (cons "Cookie"
                (format nil "~{~A=~A~^; ~}"
                        (loop for (name . value) in cookies
                              collect name
                              collect value))))))

(defun extract-session-cookie (headers)
  "Set-CookieヘッダーからセッションIDを抽出"
  (let ((set-cookie (or (gethash "set-cookie" headers)
                        (gethash "Set-Cookie" headers))))
    (when set-cookie
      (let ((session-id-match (ppcre:scan-to-strings "session_id=([^;]+)" set-cookie)))
        (when session-id-match
          (aref session-id-match 1))))))

;;;
;;; レスポンス検証
;;;

(defun assert-status (expected-status response-status)
  "HTTPステータスコードを検証"
  (ok (= expected-status response-status)
      (format nil "Expected status ~D, got ~D" expected-status response-status)))

(defun assert-json-response (body &rest keys)
  "JSONレスポンスボディを検証

  使用例:
    (assert-json-response body \"user\" \"id\")
    ; => body[\"user\"][\"id\"] が存在することを確認"
  (format t "~&[DEBUG] Response body: ~A~%" body)
  (let* ((parsed (jzon:parse body))
         (result (reduce (lambda (hash-table key)
                          (let ((key-str (string-downcase (string key))))
                            (format t "~&[DEBUG] key=~A, key-str=~A, current-value=~A~%"
                                    key key-str hash-table)
                            (when hash-table
                              (gethash key-str hash-table))))
                        keys
                        :initial-value parsed)))
    (format t "~&[DEBUG] Final result: ~A~%" result)
    (ok (not (null result))
        (format nil "Key path ~{~A~^.~} exists in JSON response" keys))))

(defun assert-cookie (name headers)
  "Set-CookieヘッダーでCookieが設定されているか検証"
  (format t "~&[DEBUG] Headers type: ~A~%" (type-of headers))
  (format t "~&[DEBUG] All headers:~%")
  (loop for key being the hash-keys of headers
        for value being the hash-values of headers
        do (format t "~&  ~A: ~A~%" key value))
  (let* ((set-cookie-raw (or (gethash "set-cookie" headers)
                             (gethash "Set-Cookie" headers)
                             (gethash :set-cookie headers)))
         ;; set-cookieの値がリストの場合は最初の要素を取得
         (set-cookie (if (listp set-cookie-raw)
                         (first set-cookie-raw)
                         set-cookie-raw)))
    (format t "~&[DEBUG] Set-Cookie header: ~A~%" set-cookie)
    (ok (and set-cookie (search name set-cookie))
        (format nil "Cookie '~A' is set" name))))

;;;
;;; 認証ヘルパー
;;;

(defmacro with-authenticated-user ((username password &optional email) &body body)
  "認証済みユーザーでテストを実行

  使用例:
    (with-authenticated-user (\"testuser\" \"password123\" \"test@example.com\")
      (let ((response (http-get \"/api/posts\" :cookies session-cookies)))
        (assert-status 200 response)))"

  `(let* ((register-response (http-post "/api/auth/register"
                                        :json (list (cons :|username| ,username)
                                                   (cons :|password| ,password)
                                                   (cons :|email| ,(or email (format nil "~A@example.com" username))))))
          (session-id (extract-session-cookie (third register-response)))
          (session-cookies (list (cons "session_id" session-id))))
     ,@body))
