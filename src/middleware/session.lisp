(defpackage voro.middleware.session
  (:use :cl)
  (:import-from :voro.redis
                :red-hset
                :red-hget
                :red-del
                :red-expire)
  (:import-from :voro.config
                :*session-ttl*)
  (:import-from :voro.util.log
                :log-info
                :log-error)
  (:export
   :generate-session-id
   :create-session
   :get-session-user-id
   :get-current-user-id
   :delete-session
   :session-exists-p))

(in-package :voro.middleware.session)

(defun generate-session-id ()
  "セッションIDを生成（128ビット = 32文字の16進数）"
  (let ((bytes (ironclad:make-random-salt 16)))  ; 16バイト = 128ビット
    (ironclad:byte-array-to-hex-string bytes)))

(defun session-key (session-id)
  "Redisキー名を生成"
  (format nil "session:~A" session-id))

(defun create-session (user-id)
  "新しいセッションを作成してセッションIDを返す
   戻り値: セッションID"
  (let ((session-id (generate-session-id)))
    (handler-case
        (progn
          ;; Redis Hashに保存
          (red-hset (session-key session-id) "user_id" (write-to-string user-id))
          (red-hset (session-key session-id) "created_at" (write-to-string (get-universal-time)))

          ;; TTL設定（7日間）
          (red-expire (session-key session-id) *session-ttl*)

          (log-info "Session created"
                    :context (list :|user_id| user-id
                                   :|session_id| session-id))
          session-id)
      (error (e)
        (log-error "Failed to create session"
                   :error e
                   :context (list :|user_id| user-id))
        (error "Session creation failed")))))

(defun get-session-user-id (session-id)
  "セッションIDからuser_idを取得
   戻り値: user_id (整数) または NIL"
  (when session-id
    (handler-case
        (let ((user-id-str (red-hget (session-key session-id) "user_id")))
          (when user-id-str
            (parse-integer user-id-str)))
      (error (e)
        (log-error "Failed to get session user_id"
                   :error e
                   :context (list :|session_id| session-id))
        nil))))

(defun delete-session (session-id)
  "セッションを削除（ログアウト）"
  (handler-case
      (progn
        (red-del (session-key session-id))
        (log-info "Session deleted"
                  :context (list :|session_id| session-id))
        t)
    (error (e)
      (log-error "Failed to delete session"
                 :error e
                 :context (list :|session_id| session-id))
      nil)))

(defun session-exists-p (session-id)
  "セッションが存在するか確認"
  (not (null (get-session-user-id session-id))))

(defun get-current-user-id (request)
  "リクエストからセッションのuser_idを取得
   戻り値: user_id (整数) または NIL（未認証の場合）"
  (let* ((cookies (lack.request:request-cookies request))
         (session-id (cdr (assoc "session_id" cookies :test #'string=))))
    (when session-id
      (get-session-user-id session-id))))
