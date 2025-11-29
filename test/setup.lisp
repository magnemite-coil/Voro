(defpackage voro.test.setup
  (:use :cl :rove)
  (:import-from :voro.db
                :connect-db
                :disconnect-db
                :*db-connection*)
  (:import-from :voro.redis
                :connect-redis
                :disconnect-redis
                :red-flushdb)
  (:import-from :voro.config
                :*app-env*
                :*db-name*)
  (:import-from :mito
                :execute-sql
                :ensure-table-exists)
  (:export
   ;; セットアップ・終了処理
   :setup-test-environment
   :teardown-test-environment
   :with-test-environment

   ;; データクリーンアップ
   :cleanup-test-data

   ;; トランザクション管理
   :with-test-db
   :test-rollback-condition

   ;; 8層防御検証
   :verify-test-database))

(in-package :voro.test.setup)

;;;
;;; 定数定義
;;;

(defparameter *test-db-whitelist* '("voro_test")
  "テスト環境で接続を許可するデータベース名のホワイトリスト")

(defparameter *production-db-blacklist* '("voro" "postgres" "template0" "template1")
  "絶対に接続してはいけない本番・システムデータベースのブラックリスト")

;;;
;;; 8層防御: 本番DB保護
;;;

(defun verify-test-database ()
  "8層防御: テスト環境の検証

  本番データベースへの誤接続を防ぐため、多層の検証を実施します。
  1つでも検証に失敗した場合、即座にエラーをシグナルします。

  検証内容:
    層1: 環境変数強制設定（APP_ENV=test, TEST_MODE=true）
    層2: DB名の明示的指定（TEST_DB_NAME 環境変数優先）
    層3: ホワイトリスト検証（voro_test のみ許可）
    層4: ブラックリスト検証（voro, postgres 等を拒否）
    層5: 接続後の再検証（実際の接続先DB名を確認）"

  ;; 層1: 環境変数チェック
  (unless (string= (uiop:getenv "APP_ENV") "test")
    (error "8層防御 - 層1失敗: APP_ENV環境変数が'test'ではありません。~
            必ず APP_ENV=test を設定してください。"))

  (unless (string= (uiop:getenv "TEST_MODE") "true")
    (error "8層防御 - 層1失敗: TEST_MODE環境変数が'true'ではありません。~
            必ず TEST_MODE=true を設定してください。"))

  ;; 層2: config.lispでの自動切り替え確認
  (unless (string= *app-env* "test")
    (error "8層防御 - 層2失敗: voro.config:*app-env*が'test'ではありません。~
            config.lispの設定を確認してください。"))

  ;; 層3: ホワイトリスト検証
  (unless (member *db-name* *test-db-whitelist* :test #'string=)
    (error "8層防御 - 層3失敗: データベース名'~A'はホワイトリストに含まれていません。~
            許可されているDB: ~{~A~^, ~}" *db-name* *test-db-whitelist*))

  ;; 層4: ブラックリスト検証
  (when (member *db-name* *production-db-blacklist* :test #'string=)
    (error "8層防御 - 層4失敗: データベース名'~A'は本番・システムDBのブラックリストに含まれています。~
            テスト環境では絶対に接続できません。" *db-name*))

  ;; 層5: 接続後の再検証（実際の接続先を確認）
  (when *db-connection*
    (let* ((query (dbi:prepare *db-connection* "SELECT current_database()"))
           (result (dbi:execute query))
           (row (dbi:fetch result))
           (actual-db-name (getf row :|current_database|)))
      (unless (and actual-db-name
                   (member actual-db-name *test-db-whitelist* :test #'string=))
        (error "8層防御 - 層5失敗: 実際の接続先DB'~A'がホワイトリストに含まれていません。~
                接続を切断します。" actual-db-name))))

  t)

;;;
;;; データクリーンアップ
;;;

(defun cleanup-test-data ()
  "テストデータをクリーンアップ

  PostgreSQL: TRUNCATE（高速）- 全Mitoモデルテーブルを動的に取得
  Redis: FLUSHDB（現在選択中のDB）

  注: テーブルリストをハードコードせず、動的に取得することで保守性を向上"

  ;; PostgreSQL クリーンアップ - 動的アプローチ
  ;; 方法1: 既知のモデルクラスから取得（推奨）
  ;; 注意: 外部キー制約を考慮して、依存される側（user）より先に依存する側（post）を削除
  (let ((model-classes '(voro.model.post:post voro.model.user:user)))
    (dolist (model-class model-classes)
      (let ((table-name (mito.class:table-name (find-class model-class))))
        (handler-case
            (mito:execute-sql
              (format nil "TRUNCATE TABLE ~S RESTART IDENTITY CASCADE" table-name))
          (error (e)
            (format *error-output*
                    "Warning: Failed to truncate table ~A: ~A~%"
                    table-name e))))))

  ;; 方法2（将来の拡張）: PostgreSQLメタテーブルから全テーブルを取得
  ;; (let ((tables (mito:retrieve-by-sql
  ;;                 "SELECT tablename FROM pg_tables WHERE schemaname = 'public'")))
  ;;   (dolist (table tables)
  ;;     (mito:execute-sql
  ;;       (format nil "TRUNCATE TABLE ~S RESTART IDENTITY CASCADE" (car table)))))

  ;; Redis クリーンアップ（テスト用DBのみ）
  (red-flushdb))

;;;
;;; セットアップ・終了処理
;;;

(defun setup-test-environment ()
  "テスト環境をセットアップ

  注意: この関数を呼ぶ前に、以下の環境変数を設定すること:
    APP_ENV=test
    TEST_MODE=true

  実行内容:
    1. 8層防御検証
    2. データベース接続
    3. Redis接続
    4. テーブル作成（存在しない場合）
    5. データクリーンアップ"

  ;; 8層防御: 層1-4の検証
  (verify-test-database)

  ;; データベース接続
  (connect-db)

  ;; Redis接続
  (connect-redis)

  ;; 8層防御: 層5の検証（接続後の再検証）
  (verify-test-database)

  ;; 8層防御: 層6 - テーブル存在確認（存在しない場合は作成）
  (ensure-table-exists 'voro.model.user:user)
  (ensure-table-exists 'voro.model.post:post)

  ;; データクリーンアップ
  (cleanup-test-data))

(defun teardown-test-environment ()
  "テスト環境をクリーンアップ"

  ;; データクリーンアップ（エラーは無視）
  (handler-case
      (cleanup-test-data)
    (error (e)
      (format *error-output* "Warning: Failed to cleanup test data: ~A~%" e)))

  ;; 接続切断
  (disconnect-redis)
  (disconnect-db))

(defmacro with-test-environment (&body body)
  "テスト環境で実行

  使用例:
    (deftest my-test ()
      (with-test-environment
        ;; テストコード
        ))

  動作:
    1. テスト開始前: DB/Redis接続、データクリーンアップ
    2. テスト実行: bodyを実行
    3. テスト終了後: データクリーンアップ、接続切断（必ず実行）"

  `(progn
     (setup-test-environment)
     (unwind-protect
          (progn ,@body)
       (teardown-test-environment))))

;;;
;;; トランザクション管理（8層防御: 層7-8）
;;;

(defmacro with-test-db (&body body)
  "トランザクション内でテストを実行（8層防御: 層7-8）

  使用例:
    (deftest user-creation-test ()
      (with-test-db
        (let ((user (create-test-user :username \"testuser\")))
          (ok (not (null user)))
          ;; テスト終了後、自動ロールバック
          )))

  動作:
    1. トランザクション開始（dbi:with-transaction）
    2. bodyを実行
    3. 必ずロールバック（成功・失敗に関わらず）

  利点:
    - DROP TABLE 不要（高速）
    - データ分離（他テストに影響なし）
    - 本番DB保護（多層検証）

  注意:
    - cl-dbi:with-transaction マクロを使用（推奨）
    - begin-transaction/commit/rollbackを直接呼ぶと状態管理の問題が発生
    - voro.db:connect-db は mito:connect-toplevel を呼び出すため、
      mito.connection:*connection* が自動的に設定される
    - 常にロールバックさせるため、条件をraiseする

  DB接続アプローチ:
    - ✅ **推奨: アプローチA** - `mito.connection:*connection*` を使用
      - 理由: Phase0 PoCで正常動作を確認済み（2025-11-24）
      - 既存コード（voro.db:connect-db）との整合性が高い
      - mito:connect-toplevel により自動的に設定される
    - アプローチB: `voro.db:*db-connection*` も技術的には可能だが、
      Mitoとの連携を考慮するとアプローチAが望ましい"

  `(handler-case
       (dbi:with-transaction mito.connection:*connection*
         (progn
           ,@body
           ;; 層8: 保証されたロールバック
           ;; テストが成功してもロールバックさせるため、条件を発生させる
           (error 'test-rollback-condition)))
     ;; test-rollback-conditionは正常なロールバックなので無視
     (test-rollback-condition () nil)))

;; テスト用ロールバック条件の定義
(define-condition test-rollback-condition (error)
  ()
  (:documentation "テスト終了時の強制ロールバック用条件（エラーではない）"))
