(defpackage voro.handler.auth
  (:use :cl :caveman2)
  (:import-from :voro.web
                :<app>)
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
                :validation-error-message))

(in-package :voro.handler.auth)

;;; ヘルパー関数

(defun get-request-body-param (key)
  "リクエストボディからパラメータを取得"
  (cdr (assoc key (lack.request:request-body-parameters *request*) :test #'string=)))

(defun set-session-cookie (session-id)
  "セッションCookieを設定"
  (setf (lack.response:response-headers *response*)
        (append (lack.response:response-headers *response*)
                (list :set-cookie
                      (format nil "session_id=~A; Path=/; HttpOnly; SameSite=Strict; Max-Age=~D"
                              session-id
                              *session-ttl*)))))

(defun clear-session-cookie ()
  "セッションCookieをクリア"
  (setf (lack.response:response-headers *response*)
        (append (lack.response:response-headers *response*)
                (list :set-cookie
                      "session_id=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0"))))

;;; ルート定義

;; ユーザー登録
(defroute (<app> "/api/auth/register" :method :POST) ()
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

              ;; セッションCookieを設定
              (set-session-cookie session-id)

              ;; 成功レスポンス
              (response-success
               (list :|user| (list :|id| (voro.model.user:user-id user)
                                   :|username| (voro.model.user:user-username user)))))

          ;; バリデーションエラー（ユーザー向けメッセージをそのまま返す）
          (validation-error (e)
            (response-error 400 (validation-error-message e)))

          ;; その他のエラー（詳細はログのみ、ユーザーには一般的なメッセージ）
          (error (e)
            (let ((error-id (log-error "Registration failed" :error e)))
              (response-error 500 "Internal server error" :error-id error-id)))))))

;; ログイン
(defroute (<app> "/api/auth/login" :method :POST) ()
  (let ((username (get-request-body-param "username"))
        (password (get-request-body-param "password")))

    ;; 入力検証
    (if (not (and username password))
        (response-error 400 "Username and password are required")

        ;; 認証
        (multiple-value-bind (user session-id)
            (authenticate-user username password)

          (if user
              (progn
                ;; セッションCookieを設定
                (set-session-cookie session-id)

                ;; 成功レスポンス
                (response-success
                 (list :|user| (list :|id| (voro.model.user:user-id user)
                                     :|username| (voro.model.user:user-username user)))))

              ;; 認証失敗
              (response-error 401 "Invalid username or password"))))))

;; ログアウト
(defroute (<app> "/api/auth/logout" :method :POST) ()
  (let* ((cookies (lack.request:request-cookies *request*))
         (session-id (cdr (assoc "session_id" cookies :test #'string=))))

    (when session-id
      (logout-user session-id))

    ;; セッションCookieをクリア
    (clear-session-cookie)

    ;; 成功レスポンス
    (response-success (list :|message| "Logged out successfully"))))
