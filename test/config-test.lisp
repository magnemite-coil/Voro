(defpackage voro.test.config
  (:use :cl :rove)
  (:import-from :voro.config
                :get-env
                :get-env-or-default
                :get-config))

(in-package :voro.test.config)

;;;
;;; ヘルパーマクロ
;;;

;; SBCL専用マクロ
;;
;; 注意: 元々未設定だった環境変数は sb-posix:unsetenv で確実に削除する。
;; 空文字を設定すると get-env が nil ではなく "" を返し、
;; nil を期待するコードが壊れる可能性がある。
;;
;; 他のCommon Lisp実装（CCL, ECL等）で使用する場合は、
;; 各実装のFFIを使った環境変数削除関数を追加する必要がある。

(defmacro with-env-var ((name value) &body body)
  "一時的に環境変数を設定してテストを実行（SBCL専用）
   復元時に未設定だった場合は sb-posix:unsetenv で確実に削除する"
  #-sbcl (error "with-env-var is SBCL-only. Other implementations require FFI for unsetenv.")
  (let ((old-value (gensym "OLD-VALUE"))
        (was-set (gensym "WAS-SET")))
    `(let* ((,old-value (uiop:getenv ,name))
            (,was-set (not (null ,old-value))))
       (unwind-protect
            (progn
              (setf (uiop:getenv ,name) ,value)
              ,@body)
         ;; 復元（SBCL専用: unsetenv で確実に未設定状態に戻す）
         (if ,was-set
             (setf (uiop:getenv ,name) ,old-value)
             ;; 元々未設定だった場合は環境変数を削除
             (sb-posix:unsetenv ,name))))))

;;;
;;; valid-port-p テスト（内部関数）
;;;

(deftest test-valid-port-p
  (testing "有効なポート番号"
    (ok (voro.config::valid-port-p 1)
        "Port 1 is valid")
    (ok (voro.config::valid-port-p 80)
        "Port 80 is valid")
    (ok (voro.config::valid-port-p 443)
        "Port 443 is valid")
    (ok (voro.config::valid-port-p 8080)
        "Port 8080 is valid")
    (ok (voro.config::valid-port-p 65535)
        "Port 65535 is valid"))

  (testing "無効なポート番号"
    (ok (not (voro.config::valid-port-p 0))
        "Port 0 is invalid")
    (ok (not (voro.config::valid-port-p -1))
        "Port -1 is invalid")
    (ok (not (voro.config::valid-port-p 65536))
        "Port 65536 is invalid")
    (ok (not (voro.config::valid-port-p nil))
        "Port nil is invalid")))

;;;
;;; valid-env-p テスト（内部関数）
;;;

(deftest test-valid-env-p
  (testing "有効な環境名"
    (ok (voro.config::valid-env-p "development")
        "development is valid")
    (ok (voro.config::valid-env-p "test")
        "test is valid")
    (ok (voro.config::valid-env-p "production")
        "production is valid"))

  (testing "無効な環境名"
    (ok (not (voro.config::valid-env-p "staging"))
        "staging is invalid")
    (ok (not (voro.config::valid-env-p "prod"))
        "prod is invalid")
    (ok (not (voro.config::valid-env-p "dev"))
        "dev is invalid")
    (ok (not (voro.config::valid-env-p nil))
        "nil is invalid")
    (ok (not (voro.config::valid-env-p ""))
        "empty string is invalid")))

;;;
;;; valid-log-level-p テスト（内部関数）
;;;

(deftest test-valid-log-level-p
  (testing "有効なログレベル"
    (ok (voro.config::valid-log-level-p :debug)
        ":debug is valid")
    (ok (voro.config::valid-log-level-p :info)
        ":info is valid")
    (ok (voro.config::valid-log-level-p :warn)
        ":warn is valid")
    (ok (voro.config::valid-log-level-p :error)
        ":error is valid"))

  (testing "無効なログレベル"
    (ok (not (voro.config::valid-log-level-p :trace))
        ":trace is invalid")
    (ok (not (voro.config::valid-log-level-p :fatal))
        ":fatal is invalid")
    (ok (not (voro.config::valid-log-level-p :warning))
        ":warning is invalid")
    (ok (not (voro.config::valid-log-level-p nil))
        "nil is invalid")))

;;;
;;; valid-redis-db-p テスト（内部関数）
;;;

(deftest test-valid-redis-db-p
  (testing "有効なRedis DB番号"
    (ok (voro.config::valid-redis-db-p 0)
        "DB 0 is valid")
    (ok (voro.config::valid-redis-db-p 1)
        "DB 1 is valid")
    (ok (voro.config::valid-redis-db-p 15)
        "DB 15 is valid"))

  (testing "無効なRedis DB番号"
    (ok (not (voro.config::valid-redis-db-p -1))
        "DB -1 is invalid")
    (ok (not (voro.config::valid-redis-db-p 16))
        "DB 16 is invalid")
    (ok (not (voro.config::valid-redis-db-p nil))
        "DB nil is invalid")))

;;;
;;; get-env テスト
;;;

(deftest test-get-env
  (testing "存在する環境変数を取得"
    ;; 一時的に設定した環境変数で検証（CI/コンテナ環境でも安定動作）
    (with-env-var ("VORO_TEST_EXISTS" "test-value")
      (ok (stringp (get-env "VORO_TEST_EXISTS"))
          "Environment variable exists")
      (ok (string= "test-value" (get-env "VORO_TEST_EXISTS"))
          "Environment variable has correct value")))

  (testing "存在しない環境変数はNILを返す"
    (ok (null (get-env "VORO_TEST_NONEXISTENT_VAR_12345"))
        "Nonexistent variable returns NIL")))

;;;
;;; get-env-or-default テスト
;;;

(deftest test-get-env-or-default
  (testing "存在する環境変数はその値を返す"
    (with-env-var ("VORO_TEST_VAR" "test-value")
      (ok (string= "test-value" (get-env-or-default "VORO_TEST_VAR" "default"))
          "Returns the environment variable value")))

  (testing "存在しない環境変数はデフォルト値を返す"
    (ok (string= "default-value"
                 (get-env-or-default "VORO_TEST_NONEXISTENT_VAR" "default-value"))
        "Returns the default value")))

;;;
;;; get-config テスト
;;;

(deftest test-get-config-string
  (testing "型変換 - :string"
    (with-env-var ("VORO_TEST_STRING" "hello")
      (ok (string= "hello" (get-config "VORO_TEST_STRING" :string "default"))
          "String value is returned as-is")))

  (testing "型変換 - :string 空文字"
    ;; 空文字は有効な値として扱われる（NILではない）
    (with-env-var ("VORO_TEST_STRING" "")
      (ok (string= "" (get-config "VORO_TEST_STRING" :string "default"))
          "Empty string is returned as-is, not default")))

  (testing "型変換 - :string 前後空白"
    ;; 前後の空白はトリムされない（そのまま返される）
    (with-env-var ("VORO_TEST_STRING" "  spaced  ")
      (ok (string= "  spaced  " (get-config "VORO_TEST_STRING" :string "default"))
          "Whitespace is preserved"))))

(deftest test-get-config-integer
  (testing "型変換 - :integer 正常値"
    (with-env-var ("VORO_TEST_INT" "8080")
      (ok (= 8080 (get-config "VORO_TEST_INT" :integer 3000))
          "String is converted to integer")))

  (testing "型変換 - :integer 不正値はデフォルトにフォールバック"
    (with-env-var ("VORO_TEST_INT" "not-a-number")
      (ok (= 3000 (get-config "VORO_TEST_INT" :integer 3000))
          "Invalid value falls back to default")))

  (testing "型変換 - :integer 空文字はデフォルトにフォールバック"
    (with-env-var ("VORO_TEST_INT" "")
      (ok (= 3000 (get-config "VORO_TEST_INT" :integer 3000))
          "Empty string falls back to default")))

  (testing "型変換 - :integer 前後空白付き数値"
    ;; parse-integer は前後空白を許容する
    (with-env-var ("VORO_TEST_INT" "  8080  ")
      (ok (= 8080 (get-config "VORO_TEST_INT" :integer 3000))
          "Whitespace around number is handled"))))

(deftest test-get-config-keyword
  (testing "型変換 - :keyword"
    (with-env-var ("VORO_TEST_KW" "info")
      (ok (eq :info (get-config "VORO_TEST_KW" :keyword :debug))
          "String is converted to keyword")))

  (testing "型変換 - :keyword 大文字小文字"
    (with-env-var ("VORO_TEST_KW" "INFO")
      (ok (eq :info (get-config "VORO_TEST_KW" :keyword :debug))
          "Keyword is upcased"))))

;; 注意: get-config の :boolean 型について
;; 実装は (member value '("true" "1" "yes" "on") :test #'string=) を返す。
;; 一致した場合はリスト（非NIL）、不一致の場合は NIL が返る。
;; テストでは (ok ...) で真偽判定を行い、(eq t ...) は使用しないこと。
;; 将来的に (not (null (member ...))) に修正して T/NIL を返すことを検討。

(deftest test-get-config-boolean
  (testing "型変換 - :boolean true値"
    (dolist (true-value '("true" "1" "yes" "on"))
      (with-env-var ("VORO_TEST_BOOL" true-value)
        ;; 非NIL（真偽値として真）が返ることを検証
        (ok (get-config "VORO_TEST_BOOL" :boolean nil)
            (format nil "~A is converted to truthy value" true-value)))))

  (testing "型変換 - :boolean true値（大文字）"
    ;; 実装は string-downcase してから比較するため大文字も真になる
    (dolist (true-value '("TRUE" "YES" "ON" "True" "Yes"))
      (with-env-var ("VORO_TEST_BOOL" true-value)
        (ok (get-config "VORO_TEST_BOOL" :boolean nil)
            (format nil "~A (uppercase) is converted to truthy value" true-value)))))

  (testing "型変換 - :boolean false値"
    (dolist (false-value '("false" "0" "no" "off" ""))
      (with-env-var ("VORO_TEST_BOOL" false-value)
        ;; NIL が返ることを検証
        (ok (not (get-config "VORO_TEST_BOOL" :boolean t))
            (format nil "~A is converted to NIL" false-value))))))

(deftest test-get-config-default
  (testing "デフォルト値 - 環境変数未設定時"
    (ok (string= "default-value"
                 (get-config "VORO_TEST_UNSET_VAR" :string "default-value"))
        "Returns default when env var is not set")))

(deftest test-get-config-validator
  (testing "バリデーション成功時は値を返す"
    (with-env-var ("VORO_TEST_PORT" "8080")
      (ok (= 8080 (get-config "VORO_TEST_PORT" :integer 3000
                              :validator #'voro.config::valid-port-p))
          "Valid value passes validation")))

  (testing "バリデーション失敗時はデフォルト値にフォールバック"
    (with-env-var ("VORO_TEST_PORT" "99999")
      (ok (= 3000 (get-config "VORO_TEST_PORT" :integer 3000
                              :validator #'voro.config::valid-port-p))
          "Invalid value falls back to default"))))

;;;
;;; get-config バリデータ連携テスト（実運用で重要な設定値）
;;; APP_ENV, LOG_LEVEL, REDIS_DB の無効値フォールバックを検証
;;;

(deftest test-get-config-validator-app-env
  (testing "APP_ENV - 有効な環境名はそのまま返す"
    (dolist (valid-env '("development" "test" "production"))
      (with-env-var ("VORO_TEST_APP_ENV" valid-env)
        (ok (string= valid-env
                     (get-config "VORO_TEST_APP_ENV" :string "development"
                                 :validator #'voro.config::valid-env-p))
            (format nil "~A is accepted" valid-env)))))

  (testing "APP_ENV - 無効な環境名はデフォルトにフォールバック"
    (dolist (invalid-env '("staging" "prod" "dev" "local" ""))
      (with-env-var ("VORO_TEST_APP_ENV" invalid-env)
        (ok (string= "development"
                     (get-config "VORO_TEST_APP_ENV" :string "development"
                                 :validator #'voro.config::valid-env-p))
            (format nil "~A falls back to default" invalid-env))))))

(deftest test-get-config-validator-log-level
  (testing "LOG_LEVEL - 有効なログレベルはそのまま返す"
    (dolist (valid-level '("debug" "info" "warn" "error"))
      (with-env-var ("VORO_TEST_LOG_LEVEL" valid-level)
        (ok (eq (intern (string-upcase valid-level) :keyword)
                (get-config "VORO_TEST_LOG_LEVEL" :keyword :info
                            :validator #'voro.config::valid-log-level-p))
            (format nil ":~A is accepted" valid-level)))))

  (testing "LOG_LEVEL - 無効なログレベルはデフォルトにフォールバック"
    (dolist (invalid-level '("trace" "fatal" "warning" "verbose" ""))
      (with-env-var ("VORO_TEST_LOG_LEVEL" invalid-level)
        (ok (eq :info
                (get-config "VORO_TEST_LOG_LEVEL" :keyword :info
                            :validator #'voro.config::valid-log-level-p))
            (format nil "~A falls back to :info" invalid-level))))))

(deftest test-get-config-validator-redis-db
  (testing "REDIS_DB - 有効なDB番号はそのまま返す"
    (dolist (valid-db '("0" "1" "8" "15"))
      (with-env-var ("VORO_TEST_REDIS_DB" valid-db)
        (ok (= (parse-integer valid-db)
               (get-config "VORO_TEST_REDIS_DB" :integer 0
                           :validator #'voro.config::valid-redis-db-p))
            (format nil "DB ~A is accepted" valid-db)))))

  (testing "REDIS_DB - 無効なDB番号はデフォルトにフォールバック"
    (dolist (invalid-db '("-1" "16" "100"))
      (with-env-var ("VORO_TEST_REDIS_DB" invalid-db)
        (ok (= 0
               (get-config "VORO_TEST_REDIS_DB" :integer 0
                           :validator #'voro.config::valid-redis-db-p))
            (format nil "DB ~A falls back to 0" invalid-db))))))

;;;
;;; Phase 1.1: Unsupported Type テスト
;;; get-config の未サポート型エラー分岐をカバー
;;;

(deftest test-get-config-unsupported-type
  (testing "サポートされていない型はデフォルト値にフォールバック"
    (with-env-var ("VORO_TEST_UNSUPPORTED" "some-value")
      ;; :invalid-type は未サポートなのでエラー → デフォルト値にフォールバック
      (ok (string= "default"
                   (get-config "VORO_TEST_UNSUPPORTED" :invalid-type "default"))
          "Unsupported type falls back to default")))

  (testing "未サポート型でも環境変数未設定時はデフォルト値を返す"
    ;; 環境変数が未設定の場合、型変換エラーより前にデフォルト値が返る
    (ok (string= "default"
                 (get-config "VORO_TEST_NONEXISTENT_UNSUPPORTED" :invalid-type "default"))
        "Unsupported type with unset env var returns default")))

;;;
;;; Phase 2: SESSION_TTL バリデーションテスト
;;; *session-ttl* のカスタムバリデータ (1-2592000) をカバー
;;;

(deftest test-get-config-validator-session-ttl
  (testing "SESSION_TTL - 有効な範囲（1-2592000）はそのまま返す"
    (dolist (valid-ttl '("1" "86400" "604800" "2592000"))
      (with-env-var ("VORO_TEST_SESSION_TTL" valid-ttl)
        (ok (= (parse-integer valid-ttl)
               (get-config "VORO_TEST_SESSION_TTL" :integer 604800
                           :validator (lambda (v) (and (> v 0) (<= v 2592000)))))
            (format nil "TTL ~A is valid" valid-ttl)))))

  (testing "SESSION_TTL - 範囲外はデフォルトにフォールバック"
    ;; 注: "-1" は parse-integer で -1 に正常パースされた後、
    ;;     バリデーション失敗でフォールバックする（Phase 1.3 とは異なる経路）
    (dolist (invalid-ttl '("0" "-1" "2592001" "9999999"))
      (with-env-var ("VORO_TEST_SESSION_TTL" invalid-ttl)
        (ok (= 604800
               (get-config "VORO_TEST_SESSION_TTL" :integer 604800
                           :validator (lambda (v) (and (> v 0) (<= v 2592000)))))
            (format nil "TTL ~A falls back to default" invalid-ttl))))))

;;;
;;; Phase 3: リトライ設定バリデーションテスト
;;; DB/Redis のリトライ設定バリデータをカバー
;;;

(deftest test-get-config-validator-retry-settings
  (testing "リトライ回数（0-10）バリデーション"
    ;; 有効値
    (dolist (valid '("0" "5" "10"))
      (with-env-var ("VORO_TEST_RETRIES" valid)
        (ok (= (parse-integer valid)
               (get-config "VORO_TEST_RETRIES" :integer 3
                           :validator (lambda (v) (and (>= v 0) (<= v 10)))))
            (format nil "Retries ~A is valid" valid))))
    ;; 無効値
    (dolist (invalid '("-1" "11" "100"))
      (with-env-var ("VORO_TEST_RETRIES" invalid)
        (ok (= 3
               (get-config "VORO_TEST_RETRIES" :integer 3
                           :validator (lambda (v) (and (>= v 0) (<= v 10)))))
            (format nil "Retries ~A falls back to default" invalid)))))

  (testing "初期リトライ遅延（1-10秒）バリデーション"
    ;; 有効値
    (dolist (valid '("1" "5" "10"))
      (with-env-var ("VORO_TEST_DELAY" valid)
        (ok (= (parse-integer valid)
               (get-config "VORO_TEST_DELAY" :integer 1
                           :validator (lambda (v) (and (> v 0) (<= v 10)))))
            (format nil "Delay ~A is valid" valid))))
    ;; 無効値（0は範囲外）
    (dolist (invalid '("0" "11" "-1"))
      (with-env-var ("VORO_TEST_DELAY" invalid)
        (ok (= 1
               (get-config "VORO_TEST_DELAY" :integer 1
                           :validator (lambda (v) (and (> v 0) (<= v 10)))))
            (format nil "Delay ~A falls back to default" invalid)))))

  (testing "最大リトライ遅延（1-120秒）バリデーション"
    ;; 有効値
    (dolist (valid '("1" "30" "120"))
      (with-env-var ("VORO_TEST_MAX_DELAY" valid)
        (ok (= (parse-integer valid)
               (get-config "VORO_TEST_MAX_DELAY" :integer 30
                           :validator (lambda (v) (and (> v 0) (<= v 120)))))
            (format nil "Max delay ~A is valid" valid))))
    ;; 無効値
    (dolist (invalid '("0" "121" "-1"))
      (with-env-var ("VORO_TEST_MAX_DELAY" invalid)
        (ok (= 30
               (get-config "VORO_TEST_MAX_DELAY" :integer 30
                           :validator (lambda (v) (and (> v 0) (<= v 120)))))
            (format nil "Max delay ~A falls back to default" invalid))))))

;;;
;;; Phase 4: 設定値参照テスト（回帰テスト）
;;; defparameter の定義が正しく行われているかを検証
;;;

(deftest test-config-parameters-defined
  (testing "設定パラメータが定義されている"
    ;; バウンド確認
    (ok (boundp 'voro.config:*app-env*) "*app-env* is bound")
    (ok (boundp 'voro.config:*app-port*) "*app-port* is bound")
    (ok (boundp 'voro.config:*db-host*) "*db-host* is bound")
    (ok (boundp 'voro.config:*db-port*) "*db-port* is bound")
    (ok (boundp 'voro.config:*redis-host*) "*redis-host* is bound")
    (ok (boundp 'voro.config:*redis-port*) "*redis-port* is bound")
    (ok (boundp 'voro.config:*session-ttl*) "*session-ttl* is bound")
    (ok (boundp 'voro.config:*log-level*) "*log-level* is bound"))

  (testing "設定パラメータの型が正しい"
    (ok (stringp voro.config:*app-env*) "*app-env* is a string")
    (ok (integerp voro.config:*app-port*) "*app-port* is an integer")
    (ok (stringp voro.config:*db-host*) "*db-host* is a string")
    (ok (integerp voro.config:*db-port*) "*db-port* is an integer")
    (ok (integerp voro.config:*session-ttl*) "*session-ttl* is an integer")
    (ok (keywordp voro.config:*log-level*) "*log-level* is a keyword")
    ;; Boolean 型パラメータ
    ;; 注: get-config の :boolean は member を返すが、
    ;;     デフォルト値が (string= *app-env* "production") の場合は t/nil が返る
    ;;     そのため、真偽値として扱う（型チェックではなく値の存在確認）
    (ok (typep voro.config:*db-health-check-enabled* '(or null cons (eql t)))
        "*db-health-check-enabled* is boolean-like (nil, list, or t)")
    (ok (typep voro.config:*redis-health-check-enabled* '(or null cons (eql t)))
        "*redis-health-check-enabled* is boolean-like (nil, list, or t)")))
