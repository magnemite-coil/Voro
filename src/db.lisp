(defpackage voro.db
  (:use :cl)
  (:import-from :voro.config
                :*db-host*
                :*db-port*
                :*db-name*
                :*db-user*
                :*db-password*
                :*app-env*
                :*db-max-retries*
                :*db-initial-retry-delay*
                :*db-max-retry-delay*
                :*db-health-check-enabled*)
  (:import-from :voro.util.log
                :log-info
                :log-error
                :log-warn
                :log-debug)
  (:export
   :connect-db
   :disconnect-db
   :*db-connection*
   :ensure-db-connected
   :db-health-check))

(in-package :voro.db)

(defparameter *db-connection* nil
  "現在のデータベース接続")

(defparameter *last-health-check-time* 0
  "最後のヘルスチェック実行時刻（universal-time）")

(defparameter *health-check-interval* 60
  "ヘルスチェック間隔（秒）- 毎回チェックしないように")

;;;
;;; ユーティリティ関数
;;;

(defun build-connection-string ()
  "接続文字列を構築"
  (format nil "postgres://~A:~A@~A:~D/~A"
          *db-user*
          *db-password*
          *db-host*
          *db-port*
          *db-name*))

(defun calculate-retry-delay (attempt)
  "リトライ待機時間を計算（エクスポネンシャルバックオフ）

   attempt: リトライ回数（0始まり）
   戻り値: 待機時間（秒）

   例:
     attempt 0 -> 1秒
     attempt 1 -> 2秒
     attempt 2 -> 4秒
     attempt 3 -> 8秒
     attempt 4 -> 16秒
     attempt 5 -> 30秒（上限）"
  (min *db-max-retry-delay*
       (* *db-initial-retry-delay* (expt 2 attempt))))

;;;
;;; 接続・切断
;;;

(defun try-connect-db ()
  "データベース接続を試行（1回）

   戻り値: 成功した場合はT、失敗した場合はNIL"
  (handler-case
      (progn
        ;; 既存接続があれば切断
        (when *db-connection*
          (handler-case
              (dbi:disconnect *db-connection*)
            (error (e)
              (log-warn "Failed to disconnect old connection"
                        :context (list :|error| (princ-to-string e))))))

        ;; 新規接続（DBI）
        (setf *db-connection*
              (dbi:connect :postgres
                           :host *db-host*
                           :port *db-port*
                           :database-name *db-name*
                           :username *db-user*
                           :password *db-password*))

        ;; Mitoに接続を設定
        (mito:connect-toplevel :postgres
                               :host *db-host*
                               :port *db-port*
                               :database-name *db-name*
                               :username *db-user*
                               :password *db-password*)

        ;; ヘルスチェックタイムスタンプを更新
        (setf *last-health-check-time* (get-universal-time))

        t)
    (error (e)
      (log-debug "Database connection attempt failed"
                 :context (list :|database| *db-name*
                                :|error| (princ-to-string e)))
      nil)))

(defun connect-db ()
  "PostgreSQLに接続（エクスポネンシャルバックオフ付きリトライ）

   戻り値: 成功した場合はT
   エラー: すべてのリトライが失敗した場合はエラーをシグナル"
  (dotimes (attempt *db-max-retries*)
    (log-info "Attempting to connect to database"
              :context (list :|attempt| (1+ attempt)
                             :|max_retries| *db-max-retries*
                             :|database| *db-name*
                             :|host| *db-host*
                             :|port| *db-port*))

    (when (try-connect-db)
      ;; 接続成功
      (log-info "Database connected"
                :context (list :|database| *db-name*
                               :|environment| *app-env*
                               :|attempt| (1+ attempt)))
      (return-from connect-db t))

    ;; 最後のリトライでない場合は待機（エクスポネンシャルバックオフ）
    (when (< attempt (1- *db-max-retries*))
      (let ((delay (calculate-retry-delay attempt)))
        (log-info "Retrying database connection"
                  :context (list :|retry_after| delay
                                 :|attempts_left| (- *db-max-retries* attempt 1)))
        (sleep delay))))

  ;; すべてのリトライが失敗
  (let ((error-id (log-error "Failed to connect to database after all retries"
                              :context (list :|database| *db-name*
                                             :|host| *db-host*
                                             :|port| *db-port*
                                             :|max_retries| *db-max-retries*))))
    (error (format nil "Database connection failed (error_id: ~A)" error-id))))

(defun disconnect-db ()
  "データベース接続を切断"
  (when *db-connection*
    (handler-case
        (progn
          (dbi:disconnect *db-connection*)
          (mito:disconnect-toplevel)
          (setf *db-connection* nil)
          (log-info "Database disconnected"))
      (error (e)
        (log-warn "Error during database disconnect"
                  :context (list :|error| (princ-to-string e)))
        ;; エラーが発生してもコネクションをクリア
        (setf *db-connection* nil)))))

;;;
;;; ヘルスチェック
;;;

(defun db-health-check ()
  "データベース接続が有効か確認

   戻り値: 有効ならT、無効ならNIL

   注: 頻繁に呼ばれる可能性があるため、*health-check-interval*秒以内の
       チェックはキャッシュされた結果を返す"
  (unless *db-health-check-enabled*
    ;; ヘルスチェックが無効な場合は接続の有無のみ確認
    (return-from db-health-check (not (null *db-connection*))))

  ;; 接続が存在しない場合は即座にNIL
  (unless *db-connection*
    (return-from db-health-check nil))

  ;; 最後のチェックから十分な時間が経過していない場合はスキップ
  (let ((current-time (get-universal-time)))
    (when (< (- current-time *last-health-check-time*) *health-check-interval*)
      (log-debug "Skipping health check (too soon)"
                 :context (list :|last_check| *last-health-check-time*
                                :|interval| *health-check-interval*))
      (return-from db-health-check t)))

  ;; 実際にヘルスチェックを実行
  (handler-case
      (progn
        (log-debug "Executing database health check")
        ;; 簡単なクエリで接続確認
        (dbi:execute (dbi:prepare *db-connection* "SELECT 1"))
        ;; チェック成功、タイムスタンプ更新
        (setf *last-health-check-time* (get-universal-time))
        (log-debug "Database health check passed")
        t)
    (error (e)
      (log-warn "Database health check failed"
                :context (list :|error| (princ-to-string e)))
      ;; 接続が切れているのでクリア（mito接続も含めて）
      (setf *db-connection* nil)
      (handler-case
          (mito:disconnect-toplevel)
        (error (disconnect-error)
          (log-debug "Failed to disconnect mito toplevel during health check cleanup"
                     :context (list :|error| (princ-to-string disconnect-error)))))
      nil)))

(defun ensure-db-connected ()
  "データベースが接続されているか確認（未接続または切断されていれば再接続）

   戻り値: 接続が確立されている場合はT
   エラー: 再接続に失敗した場合はエラーをシグナル"
  (unless (db-health-check)
    (log-warn "Database connection lost or not established, reconnecting...")
    (connect-db)))
