(defpackage voro.redis
  (:use :cl)
  (:import-from :voro.config
                :*redis-host*
                :*redis-port*
                :*redis-db*
                :*redis-max-retries*
                :*redis-initial-retry-delay*
                :*redis-max-retry-delay*
                :*redis-health-check-enabled*)
  (:import-from :voro.util.log
                :log-info
                :log-error
                :log-warn
                :log-debug)
  (:export
   :connect-redis
   :disconnect-redis
   :*redis-connection*
   :ensure-redis-connected
   :redis-health-check
   :red-set
   :red-get
   :red-del
   :red-expire
   :red-hset
   :red-hget
   :red-hgetall
   :red-ttl
   :red-select
   :red-flushdb))

(in-package :voro.redis)

(defparameter *redis-connection* nil
  "Redis接続オブジェクト（接続状態の追跡用）

   注: cl-redisライブラリは内部的に接続状態をグローバルに管理するため、
       この変数は主に接続が確立されているかを判定するフラグとして機能します。
       実際のRedisコマンド（red-set, red-getなど）は、この変数を直接使用せず、
       cl-redisの内部接続状態を利用します。")

(defparameter *last-health-check-time* 0
  "最後のヘルスチェック実行時刻（universal-time）")

(defparameter *health-check-interval* 60
  "ヘルスチェック間隔（秒）- 毎回チェックしないように")

;;;
;;; ユーティリティ関数
;;;

(defun calculate-retry-delay (attempt)
  "リトライ待機時間を計算（エクスポネンシャルバックオフ）

   attempt: リトライ回数（0始まり）
   戻り値: 待機時間（秒）"
  (min *redis-max-retry-delay*
       (* *redis-initial-retry-delay* (expt 2 attempt))))

;;;
;;; 接続・切断
;;;

(defun try-connect-redis ()
  "Redis接続を試行（1回）

   戻り値: 成功した場合はT、失敗した場合はNIL"
  (handler-case
      (progn
        ;; 既存接続があれば切断
        (when *redis-connection*
          (handler-case
              (redis:disconnect)
            (error (e)
              (log-warn "Failed to disconnect old Redis connection"
                        :context (list :|error| (princ-to-string e))))))

        ;; 新規接続
        (setf *redis-connection*
              (redis:connect :host *redis-host*
                             :port *redis-port*))

        ;; DB選択
        (redis:red-select *redis-db*)

        ;; ヘルスチェックタイムスタンプを更新
        (setf *last-health-check-time* (get-universal-time))

        t)
    (error (e)
      (log-debug "Redis connection attempt failed"
                 :context (list :|host| *redis-host*
                                :|port| *redis-port*
                                :|db| *redis-db*
                                :|error| (princ-to-string e)))
      ;; 接続が中途半端な状態になっている可能性があるためクリア
      ;; （redis:connect成功後にredis:red-select失敗のケース等）
      ;; 注: disconnect-redis を使用することで、ログ出力と状態クリアを統一。
      ;; disconnect-redis は log-info を出力するため、log-debug と併せて
      ;; 2つのログが出力されるが、一貫性とトレーサビリティを優先する。
      (disconnect-redis)
      nil)))

(defun connect-redis ()
  "Redisに接続（エクスポネンシャルバックオフ付きリトライ）

   戻り値: 成功した場合はT
   エラー: すべてのリトライが失敗した場合はエラーをシグナル"
  (dotimes (attempt *redis-max-retries*)
    (log-info "Attempting to connect to Redis"
              :context (list :|attempt| (1+ attempt)
                             :|max_retries| *redis-max-retries*
                             :|host| *redis-host*
                             :|port| *redis-port*
                             :|db| *redis-db*))

    (when (try-connect-redis)
      ;; 接続成功
      (log-info "Redis connected"
                :context (list :|host| *redis-host*
                               :|port| *redis-port*
                               :|db| *redis-db*
                               :|attempt| (1+ attempt)))
      (return-from connect-redis t))

    ;; 最後のリトライでない場合は待機（エクスポネンシャルバックオフ）
    (when (< attempt (1- *redis-max-retries*))
      (let ((delay (calculate-retry-delay attempt)))
        (log-info "Retrying Redis connection"
                  :context (list :|retry_after| delay
                                 :|attempts_left| (- *redis-max-retries* attempt 1)))
        (sleep delay))))

  ;; すべてのリトライが失敗
  (let ((error-id (log-error "Failed to connect to Redis after all retries"
                              :context (list :|host| *redis-host*
                                             :|port| *redis-port*
                                             :|db| *redis-db*
                                             :|max_retries| *redis-max-retries*))))
    (error (format nil "Redis connection failed (error_id: ~A)" error-id))))

(defun disconnect-redis ()
  "Redis接続を切断"
  (when *redis-connection*
    (handler-case
        (progn
          (redis:disconnect)
          (setf *redis-connection* nil)
          (log-info "Redis disconnected"))
      (error (e)
        (log-warn "Error during Redis disconnect"
                  :context (list :|error| (princ-to-string e)))
        ;; エラーが発生してもコネクションをクリア
        (setf *redis-connection* nil)))))

;;;
;;; ヘルスチェック
;;;

(defun redis-health-check ()
  "Redis接続が有効か確認

   戻り値: 有効ならT、無効ならNIL

   注: 頻繁に呼ばれる可能性があるため、*health-check-interval*秒以内の
       チェックはキャッシュされた結果を返す"
  (unless *redis-health-check-enabled*
    ;; ヘルスチェックが無効な場合は接続の有無のみ確認
    (return-from redis-health-check (not (null *redis-connection*))))

  ;; 接続が存在しない場合は即座にNIL
  (unless *redis-connection*
    (return-from redis-health-check nil))

  ;; 最後のチェックから十分な時間が経過していない場合はスキップ
  (let ((current-time (get-universal-time)))
    (when (< (- current-time *last-health-check-time*) *health-check-interval*)
      (log-debug "Skipping Redis health check (too soon)"
                 :context (list :|last_check| *last-health-check-time*
                                :|interval| *health-check-interval*))
      (return-from redis-health-check t)))

  ;; 実際にヘルスチェックを実行
  (handler-case
      (progn
        (log-debug "Executing Redis health check")
        ;; PINGコマンドで接続確認
        (redis:red-ping)
        ;; チェック成功、タイムスタンプ更新
        (setf *last-health-check-time* (get-universal-time))
        (log-debug "Redis health check passed")
        t)
    (error (e)
      (log-warn "Redis health check failed"
                :context (list :|error| (princ-to-string e)))
      ;; 接続が切れているのでクリア
      (setf *redis-connection* nil)
      nil)))

(defun ensure-redis-connected ()
  "Redisが接続されているか確認（未接続または切断されていれば再接続）

   戻り値: 接続が確立されている場合はT
   エラー: 再接続に失敗した場合はエラーをシグナル"
  (unless (redis-health-check)
    (log-warn "Redis connection lost or not established, reconnecting...")
    (connect-redis)))

;;;
;;; Redisコマンドラッパー（自動ヘルスチェック付き）
;;;

(defun red-set (key value)
  "SET コマンド（自動ヘルスチェック付き）"
  (ensure-redis-connected)
  (redis:red-set key value))

(defun red-get (key)
  "GET コマンド（自動ヘルスチェック付き）"
  (ensure-redis-connected)
  (redis:red-get key))

(defun red-del (key)
  "DEL コマンド（自動ヘルスチェック付き）"
  (ensure-redis-connected)
  (redis:red-del key))

(defun red-expire (key seconds)
  "EXPIRE コマンド（自動ヘルスチェック付き）"
  (ensure-redis-connected)
  (redis:red-expire key seconds))

(defun red-hset (key field value)
  "HSET コマンド（自動ヘルスチェック付き）"
  (ensure-redis-connected)
  (redis:red-hset key field value))

(defun red-hget (key field)
  "HGET コマンド（自動ヘルスチェック付き）"
  (ensure-redis-connected)
  (redis:red-hget key field))

(defun red-hgetall (key)
  "HGETALL コマンド（自動ヘルスチェック付き）"
  (ensure-redis-connected)
  (redis:red-hgetall key))

(defun red-ttl (key)
  "TTL コマンド（自動ヘルスチェック付き）"
  (ensure-redis-connected)
  (redis:red-ttl key))

(defun red-select (db)
  "SELECT コマンド（ヘルスチェックなし - 初期接続時のみ使用）"
  (redis:red-select db))

(defun red-flushdb ()
  "FLUSHDB コマンド（ヘルスチェックなし - テスト専用）
   警告: このコマンドは現在選択中のデータベースの全データを削除します。
         テスト環境でのみ使用してください。"
  (redis:red-flushdb))
