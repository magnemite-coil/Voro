(defpackage voro
  (:use :cl)
  (:import-from :voro.config
                :*app-port*)
  (:import-from :voro.db
                :connect-db
                :disconnect-db)
  (:import-from :voro.redis
                :connect-redis
                :disconnect-redis)
  (:import-from :voro.util.log
                :log-info
                :log-warn
                :log-error)
  (:export
   :start
   :stop))

(in-package :voro)

(defparameter *server* nil
  "Wooサーバーインスタンス")

(defun initialize-tables ()
  "Mitoテーブルを初期化（存在しなければ作成）"
  (log-info "Initializing database tables...")

  ;; モデルをロード（依存関係順）
  (mito:ensure-table-exists 'voro.model.user:user)

  (log-info "Database tables initialized"))

(defun start (&key (port *app-port*) (use-thread nil))
  "アプリケーションを起動
   use-thread: t でバックグラウンドスレッドで起動（テスト用）"
  (handler-case
      (progn
        (log-info "Starting Voro application..."
                  :context (list :|port| port))

        ;; データベース接続
        (connect-db)

        ;; Redis接続
        (connect-redis)

        ;; テーブル初期化
        (initialize-tables)

        ;; Webサーバー起動
        ;; 注: セッション管理は独自実装（src/middleware/session.lisp）を使用
        ;;     Lackのセッションミドルウェアは使用しない
        (setf *server*
              (clack:clackup voro.web:*app*
                             :server :woo
                             :port port
                             :use-thread use-thread))

        (log-info "Voro started successfully"
                  :context (list :|port| port))

        (unless use-thread
          (format t "~%Server running at http://localhost:~D/~%" port)
          (format t "Press Ctrl+C to stop~%~%")))
    (error (e)
      (log-error "Failed to start application" :error e)
      (stop)
      (error e))))

(defun stop ()
  "アプリケーションを停止"
  (log-info "Stopping Voro application...")

  ;; Webサーバー停止
  (let ((server-stop-failed nil))
    (when *server*
      (handler-case
          (progn
            (clack:stop *server*)
            (setf *server* nil))
        (error (e)
          (log-error "Failed to stop server - resources not released"
                     :context (list :|error| (princ-to-string e)))
          (setf server-stop-failed t))))

    (if server-stop-failed
        ;; 停止失敗時: DB/Redis は切断しない（サーバーがまだ使用中の可能性）
        (log-error "Voro stop incomplete - server may still be running")
        ;; 停止成功時（またはサーバー未起動時）: DB/Redis を切断
        (progn
          (disconnect-redis)
          (disconnect-db)
          (log-info "Voro stopped")))))
