(defpackage voro.service.auth
  (:use :cl)
  (:import-from :voro.model.user
                :find-user-by-username
                :create-user
                :verify-user-password)
  (:import-from :voro.middleware.session
                :create-session
                :delete-session)
  (:import-from :voro.util.log
                :log-info
                :log-error)
  (:import-from :voro.util.validation
                :validate-password
                :validate-username
                :validate-email
                :validation-error
                :validation-error-message)
  (:export
   :register-user
   :authenticate-user
   :logout-user))

(in-package :voro.service.auth)

(defun register-user (username password &key email)
  "新規ユーザー登録
   戻り値: (values user session-id) または エラー"
  (handler-case
      (progn
        ;; 入力バリデーション
        (validate-username username)
        (validate-password password)
        (validate-email email)

        ;; ユーザー名の重複チェック
        (when (find-user-by-username username)
          (error 'validation-error
                 :message "Username already exists"))

        ;; ユーザー作成
        (let ((user (create-user username password :email email)))
          (log-info "User registered"
                    :context (list :|username| username))

          ;; セッション作成
          (let ((session-id (create-session (voro.model.user:user-id user))))
            (values user session-id))))

    ;; バリデーションエラーは再スロー（ユーザー向けメッセージ）
    (validation-error (e)
      (log-info "User registration validation failed"
                :context (list :|username| username
                               :|error| (validation-error-message e)))
      (error e))

    ;; その他のエラー
    (error (e)
      (log-error "User registration failed"
                 :error e
                 :context (list :|username| username))
      (error e))))

(defun authenticate-user (username password)
  "ユーザー認証（ログイン）
   戻り値: (values user session-id) または NIL"
  (handler-case
      (let ((user (find-user-by-username username)))
        (cond
          ;; ユーザーが存在しない
          ((null user)
           (log-info "Login failed: user not found"
                     :context (list :|username| username))
           nil)

          ;; パスワードが不一致
          ((not (verify-user-password user password))
           (log-info "Login failed: invalid password"
                     :context (list :|username| username))
           nil)

          ;; 認証成功
          (t
           (let ((session-id (create-session (voro.model.user:user-id user))))
             (log-info "User logged in"
                       :context (list :|username| username))
             (values user session-id)))))
    (error (e)
      (log-error "Authentication error"
                 :error e
                 :context (list :|username| username))
      nil)))

(defun logout-user (session-id)
  "ログアウト（セッション削除）"
  (delete-session session-id))
