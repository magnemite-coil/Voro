(defpackage voro.test.setup
  (:use :cl :rove)
  (:import-from :voro.db
                :connect-db
                :disconnect-db)
  (:import-from :voro.redis
                :connect-redis
                :disconnect-redis
                :red-flushdb)
  (:export
   :setup-test-environment
   :teardown-test-environment
   :with-test-environment
   :cleanup-test-data))

(in-package :voro.test.setup)

(defun cleanup-test-data ()
  "テストデータをクリーンアップ

   PostgreSQL: 全テーブルをTRUNCATE
   Redis: 現在選択中のDB（テスト用DB）の全キーを削除"

  ;; PostgreSQL クリーンアップ
  (mito:execute-sql "TRUNCATE TABLE \"user\" RESTART IDENTITY CASCADE")

  ;; Redis クリーンアップ（テスト用DBのみ）
  ;; 注: connect-redis()で既にテスト用DB（*redis-db*）が選択されている
  (red-flushdb))

(defun setup-test-environment ()
  "テスト環境をセットアップ

   注意: この関数を呼ぶ前に、環境変数 APP_ENV=test を設定すること。
   例: $ APP_ENV=test sbcl --eval '(ql:quickload :voro/test)' --eval '(asdf:test-system :voro)'"

  ;; 接続（config.lispで既にAPP_ENV=testに基づいて設定が読み込まれている前提）
  (connect-db)
  (connect-redis)

  ;; テーブル初期化（存在しない場合は作成）
  (mito:ensure-table-exists 'voro.model.user:user)

  ;; 既存のテストデータをクリーンアップ
  (cleanup-test-data))

(defun teardown-test-environment ()
  "テスト環境をクリーンアップ"
  ;; テストデータを確実にクリーンアップ
  (handler-case
      (cleanup-test-data)
    (error (e)
      (format *error-output* "Warning: Failed to cleanup test data: ~A~%" e)))

  ;; 接続を切断
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
