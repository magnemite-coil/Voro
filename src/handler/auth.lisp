(defpackage voro.handler.auth
  (:use :cl :caveman2)
  (:import-from :voro.web
                :*app*)
  (:import-from :voro.service.auth
                :register-user
                :authenticate-user
                :logout-user)
  (:import-from :voro.config
                :*session-ttl*)
  (:import-from :voro.util.response
                :response-success
                :response-error)
  (:import-from :voro.util.log
                :log-error)
  (:import-from :voro.util.validation
                :validation-error
                :validation-error-message)
  (:import-from :voro.util.request
                :get-body-param))

(in-package :voro.handler.auth)

;;; ヘルパー関数

(defun get-request-body-param (key)
  "リクエストボディからパラメータを取得（共通ユーティリティのラッパー）"
  (get-body-param (lack.request:request-body-parameters *request*) key))

(defun make-session-cookie-header (session-id)
  "セッションCookie用のヘッダーを生成"
  (list :set-cookie
        (format nil "session_id=~A; Path=/; HttpOnly; SameSite=Strict; Max-Age=~D"
                session-id
                *session-ttl*)))

(defun make-clear-cookie-header ()
  "セッションCookie削除用のヘッダーを生成"
  (list :set-cookie
        "session_id=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0"))

;;; ルート定義

;; ユーザー登録
(defroute (*app* "/api/auth/register" :method :POST) ()
  (let ((username (get-request-body-param "username"))
        (password (get-request-body-param "password"))
        (email (get-request-body-param "email")))

    ;; 入力検証
    (if (not (and username password))
        (response-error 400 "Username and password are required")

        ;; ユーザー登録
        (handler-case
            (multiple-value-bind (user session-id)
                (register-user username password :email email)

              ;; 成功レスポンス（セッションCookie付き）
              (response-success
               (list (cons :|user| (list (cons :|id| (voro.model.user:user-id user))
                                         (cons :|username| (voro.model.user:user-username user)))))
               :headers (make-session-cookie-header session-id)))

          ;; バリデーションエラー（ユーザー向けメッセージをそのまま返す）
          (validation-error (e)
            (response-error 400 (validation-error-message e)))

          ;; その他のエラー（詳細はログのみ、ユーザーには一般的なメッセージ）
          (error (e)
            (let ((error-id (log-error "Registration failed" :error e)))
              (response-error 500 "Internal server error" :error-id error-id)))))))

;; ログイン
(defroute (*app* "/api/auth/login" :method :POST) ()
  (let ((username (let ((val (get-request-body-param "username")))
                    (when val (string-trim '(#\Space #\Tab) val))))
        (password (let ((val (get-request-body-param "password")))
                    (when val (string-trim '(#\Space #\Tab) val)))))

    ;; 入力検証
    (if (not (and username password))
        (response-error 400 "Username and password are required")

        ;; 認証
        (multiple-value-bind (user session-id)
            (authenticate-user username password)

          (if user
              ;; 成功レスポンス（セッションCookie付き）
              (response-success
               (list (cons :|user| (list (cons :|id| (voro.model.user:user-id user))
                                         (cons :|username| (voro.model.user:user-username user)))))
               :headers (make-session-cookie-header session-id))

              ;; 認証失敗
              (response-error 401 "Invalid username or password"))))))

;; ログアウト
(defroute (*app* "/api/auth/logout" :method :POST) ()
  (let* ((cookies (lack.request:request-cookies *request*))
         (session-id (cdr (assoc "session_id" cookies :test #'string=))))

    (when session-id
      (logout-user session-id))

    ;; 成功レスポンス（Cookie削除ヘッダー付き）
    (response-success (list (cons :|message| "Logged out successfully"))
                     :headers (make-clear-cookie-header))))
