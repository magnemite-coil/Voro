(defpackage voro.config
  (:use :cl)
  (:export
   ;; 環境変数取得関数
   :get-config
   :get-env
   :get-env-or-default

   ;; 設定値
   :*app-env*
   :*app-port*
   :*db-host*
   :*db-port*
   :*db-name*
   :*db-user*
   :*db-password*
   :*redis-host*
   :*redis-port*
   :*redis-db*
   :*session-ttl*
   :*log-level*
   :*log-file*
   :*db-max-retries*
   :*db-initial-retry-delay*
   :*db-max-retry-delay*
   :*db-health-check-enabled*
   :*redis-max-retries*
   :*redis-initial-retry-delay*
   :*redis-max-retry-delay*
   :*redis-health-check-enabled*

   ;; 将来追加予定（S3設定）
   :*s3-access-key-id*
   :*s3-secret-access-key*
   :*s3-bucket-name*
   :*s3-region*))

(in-package :voro.config)

;;;
;;; 型安全な環境変数読み込み
;;;

(defun get-env (name)
  "環境変数を取得（存在しない場合はNIL）"
  (uiop:getenv name))

(defun get-env-or-default (name default)
  "環境変数を取得（存在しない場合はデフォルト値）"
  (or (get-env name) default))

(defun get-config (name type default &key validator description)
  "型安全な環境変数取得

  引数:
    name: 環境変数名（文字列）
    type: 型指定 (:string, :integer, :keyword, :boolean)
    default: デフォルト値
    validator: オプションの検証関数（lambda）
    description: オプションの説明文（エラーメッセージ用）

  戻り値:
    パース済みの値（失敗時はデフォルト値）

  例:
    (get-config \"APP_PORT\" :integer 8080
                :validator (lambda (v) (and (> v 0) (< v 65536)))
                :description \"Application port number\")"

  (let ((env-value (get-env name)))
    (handler-case
        (let ((parsed-value
                (cond
                  ;; 環境変数が未設定の場合はデフォルト値
                  ((null env-value) default)

                  ;; 型に応じてパース
                  ((eq type :string) env-value)

                  ((eq type :integer)
                   (parse-integer env-value))

                  ((eq type :keyword)
                   (intern (string-upcase env-value) :keyword))

                  ((eq type :boolean)
                   (member (string-downcase env-value)
                           '("true" "1" "yes" "on")
                           :test #'string=))

                  (t (error "Unsupported type: ~A" type)))))

          ;; バリデーション（指定されている場合）
          (when (and validator (not (funcall validator parsed-value)))
            (error "Validation failed for ~A~@[: ~A~]" name description))

          parsed-value)

      (error (e)
        ;; エラーメッセージを出力してデフォルト値を返す
        ;; 注: この時点ではログシステムが初期化されていない可能性があるため
        ;;     標準エラー出力を使用
        (format *error-output*
                "CONFIG WARNING: Failed to parse ~A='~A' (~A)~%"
                name env-value e)
        (format *error-output*
                "CONFIG WARNING: Using default value: ~A~@[ (~A)~]~%~%"
                default description)
        default))))

;;;
;;; 共通バリデーション関数
;;;

(defun valid-port-p (port)
  "ポート番号の妥当性チェック（1-65535）"
  (and (integerp port) (> port 0) (< port 65536)))

(defun valid-env-p (env)
  "アプリケーション環境の妥当性チェック"
  (member env '("development" "test" "production") :test #'string=))

(defun valid-log-level-p (level)
  "ログレベルの妥当性チェック"
  (member level '(:debug :info :warn :error)))

(defun valid-redis-db-p (db)
  "Redis DB番号の妥当性チェック（0-15）"
  (and (integerp db) (>= db 0) (<= db 15)))

;;;
;;; 設定値の定義
;;;

;; アプリケーション設定
(defparameter *app-env*
  (get-config "APP_ENV" :string "development"
              :validator #'valid-env-p
              :description "Application environment (development, test, production)")
  "アプリケーション環境 (development, test, production)")

(defparameter *app-port*
  (get-config "APP_PORT" :integer 8080
              :validator #'valid-port-p
              :description "Application port number")
  "アプリケーションポート番号")

;; PostgreSQL設定
(defparameter *db-host*
  (get-config "DB_HOST" :string "localhost"
              :description "PostgreSQL host")
  "PostgreSQLホスト")

(defparameter *db-port*
  (get-config "DB_PORT" :integer 5432
              :validator #'valid-port-p
              :description "PostgreSQL port")
  "PostgreSQLポート")

(defparameter *db-name*
  (if (string= *app-env* "test")
      (get-config "TEST_DB_NAME" :string "voro_test"
                  :description "Test database name")
      (get-config "DB_NAME" :string "voro"
                  :description "Database name"))
  "データベース名（テスト環境では自動的にテストDB）")

(defparameter *db-user*
  (if (string= *app-env* "test")
      (get-config "TEST_DB_USER" :string "voro_test_user"
                  :description "Test database user")
      (get-config "DB_USER" :string "voro_user"
                  :description "Database user"))
  "データベースユーザー")

(defparameter *db-password*
  (if (string= *app-env* "test")
      (get-config "TEST_DB_PASSWORD" :string "voro_test_password"
                  :description "Test database password")
      (get-config "DB_PASSWORD" :string "voro_password"
                  :description "Database password"))
  "データベースパスワード")

;; Redis設定
(defparameter *redis-host*
  (get-config "REDIS_HOST" :string "localhost"
              :description "Redis host")
  "Redisホスト")

(defparameter *redis-port*
  (get-config "REDIS_PORT" :integer 6379
              :validator #'valid-port-p
              :description "Redis port")
  "Redisポート")

(defparameter *redis-db*
  (get-config (if (string= *app-env* "test") "TEST_REDIS_DB" "REDIS_DB")
              :integer (if (string= *app-env* "test") 1 0)
              :validator #'valid-redis-db-p
              :description "Redis database number (0-15)")
  "Redis DB番号（テスト環境では自動的に別DB）")

;; セッション設定
(defparameter *session-ttl*
  (get-config "SESSION_TTL" :integer 604800
              :validator (lambda (v) (and (> v 0) (<= v 2592000)))  ; 最大30日
              :description "Session TTL in seconds (max 30 days)")
  "セッション有効期限（秒）")

;; ログ設定
(defparameter *log-level*
  (get-config "LOG_LEVEL" :keyword :info
              :validator #'valid-log-level-p
              :description "Log level (:debug :info :warn :error)")
  "ログレベル (:debug :info :warn :error)")

(defparameter *log-file*
  (get-config "LOG_FILE" :string "var/log/voro.log"
              :description "Log file path")
  "ログファイルパス")

;;;
;;; データベース接続設定
;;;

(defparameter *db-max-retries*
  (get-config "DB_MAX_RETRIES" :integer
              (if (string= *app-env* "production") 5 3)
              :validator (lambda (v) (and (>= v 0) (<= v 10)))
              :description "Database connection max retries (0-10)")
  "DB接続の最大リトライ回数（本番: 5回、開発/テスト: 3回）")

(defparameter *db-initial-retry-delay*
  (get-config "DB_INITIAL_RETRY_DELAY" :integer 1
              :validator (lambda (v) (and (> v 0) (<= v 10)))
              :description "Database connection initial retry delay (seconds)")
  "DB接続リトライの初期待機時間（秒）")

(defparameter *db-max-retry-delay*
  (get-config "DB_MAX_RETRY_DELAY" :integer 30
              :validator (lambda (v) (and (> v 0) (<= v 120)))
              :description "Database connection max retry delay (seconds)")
  "DB接続リトライの最大待機時間（秒）")

(defparameter *db-health-check-enabled*
  (get-config "DB_HEALTH_CHECK_ENABLED" :boolean
              (string= *app-env* "production")
              :description "Enable database health check (recommended for production)")
  "DBヘルスチェックを有効化（本番環境推奨）")

;;;
;;; Redis接続設定
;;;

(defparameter *redis-max-retries*
  (get-config "REDIS_MAX_RETRIES" :integer
              (if (string= *app-env* "production") 5 3)
              :validator (lambda (v) (and (>= v 0) (<= v 10)))
              :description "Redis connection max retries (0-10)")
  "Redis接続の最大リトライ回数（本番: 5回、開発/テスト: 3回）")

(defparameter *redis-initial-retry-delay*
  (get-config "REDIS_INITIAL_RETRY_DELAY" :integer 1
              :validator (lambda (v) (and (> v 0) (<= v 10)))
              :description "Redis connection initial retry delay (seconds)")
  "Redis接続リトライの初期待機時間（秒）")

(defparameter *redis-max-retry-delay*
  (get-config "REDIS_MAX_RETRY_DELAY" :integer 30
              :validator (lambda (v) (and (> v 0) (<= v 120)))
              :description "Redis connection max retry delay (seconds)")
  "Redis接続リトライの最大待機時間（秒）")

(defparameter *redis-health-check-enabled*
  (get-config "REDIS_HEALTH_CHECK_ENABLED" :boolean
              (string= *app-env* "production")
              :description "Enable Redis health check (recommended for production)")
  "Redisヘルスチェックを有効化（本番環境推奨）")

;;;
;;; S3設定（将来追加予定 - フェーズ4以降で使用）
;;;

(defparameter *s3-access-key-id*
  (get-config "AWS_ACCESS_KEY_ID" :string nil
              :description "AWS Access Key ID for S3")
  "AWS S3 アクセスキーID（未設定の場合はNIL）")

(defparameter *s3-secret-access-key*
  (get-config "AWS_SECRET_ACCESS_KEY" :string nil
              :description "AWS Secret Access Key for S3")
  "AWS S3 シークレットアクセスキー（未設定の場合はNIL）")

(defparameter *s3-bucket-name*
  (get-config "S3_BUCKET_NAME" :string nil
              :description "S3 bucket name for file storage")
  "S3 バケット名（未設定の場合はNIL）")

(defparameter *s3-region*
  (get-config "S3_REGION" :string "ap-northeast-1"
              :description "S3 region (default: Tokyo)")
  "S3 リージョン（デフォルト: 東京）")
