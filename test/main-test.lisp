(defpackage voro.test.main
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment
                :verify-test-database)
  (:import-from :voro
                :start
                :stop)
  (:import-from :voro.db
                :*db-connection*
                :connect-db
                :disconnect-db)
  (:import-from :voro.redis
                :*redis-connection*
                :connect-redis
                :disconnect-redis))

(in-package :voro.test.main)

;;;
;;; ヘルパー
;;;

(defparameter *test-main-port* 18081
  "main-test 専用ポート（http-helper の 18080 と競合回避）")

(defmacro with-clean-server-state (&body body)
  "サーバー状態をクリーンに保つマクロ。
   テスト前に *server* を NIL に初期化し、テスト後にサーバーが起動していれば停止する。
   元の状態には戻さない（テスト間の独立性確保のため）。"
  `(unwind-protect
        (progn
          (setf voro::*server* nil)
          ,@body)
     ;; サーバーが起動していれば停止
     (when voro::*server*
       (handler-case
           (stop)
         (error () nil)))))

;;;
;;; ヘルパー: テーブル存在確認
;;;

(defun table-exists-in-pg-p (table-name)
  "PostgreSQL の pg_tables を使ってテーブルの存在を確認する。
   Mito標準APIにtable-exists-p相当の関数が提供されていないため、この関数で代替する。
   table-name は英数字とアンダースコアのみ許可（SQLインジェクション対策）。"
  ;; 入力バリデーション: 英数字とアンダースコアのみ許可
  (unless (and (stringp table-name)
               (plusp (length table-name))
               (every (lambda (c)
                        (or (alphanumericp c)
                            (char= c #\_)))
                      table-name))
    (error "Invalid table name: ~A (only alphanumeric and underscore allowed)" table-name))
  (let* ((query (format nil
                        "SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = '~A' LIMIT 1"
                        table-name))
         (result (mito:retrieve-by-sql query)))
    ;; 結果があればテーブルが存在する（キーワード形式に依存しない）
    (not (null result))))

;;;
;;; initialize-tables テスト
;;; 注: with-test-environment は ensure-table-exists を先に呼ぶため使用しない。
;;;     DB/Redis 接続のみ手動で管理し、initialize-tables の効果を直接検証する。
;;; 注: テストDBには既にテーブルが存在する可能性があるため、このテストは
;;;     「新規作成」ではなく「冪等性」を検証する。
;;;

(deftest test-initialize-tables
  ;; DB/Redis 接続のセットアップ（テーブル作成なし）
  (verify-test-database)
  (connect-db)
  (connect-redis)

  (unwind-protect
      (progn
        (testing "テーブル初期化が成功する"
          ;; initialize-tables は内部関数のため voro:: で呼び出し
          ;; 戻り値ではなく、エラーが発生しないことを検証
          (handler-case
              (progn
                (voro::initialize-tables)
                (ok t "initialize-tables should complete without error"))
            (error (e)
              (declare (ignore e))
              (ok nil "initialize-tables raised an error"))))

        (testing "user テーブルが存在する"
          (let ((exists (table-exists-in-pg-p "user")))
            (ok exists
                "user table should exist after initialization")))

        (testing "二重呼び出しの冪等性"
          ;; 2回呼び出してもエラーにならないこと
          (handler-case
              (progn
                (voro::initialize-tables)
                (voro::initialize-tables)
                (ok t "Double initialization should not raise error"))
            (error (e)
              (declare (ignore e))
              (ok nil "Double initialization raised an error")))))

    ;; クリーンアップ
    (disconnect-redis)
    (disconnect-db)))

;;;
;;; *server* 状態管理テスト
;;;

(deftest test-server-state-management
  (with-clean-server-state
    (testing "with-clean-server-state で *server* は NIL に初期化される"
      (ok (null voro::*server*)
          "*server* should be NIL in clean state"))

    (testing "*server* は defparameter で定義されている"
      ;; *server* がシンボルとして存在し、バウンドされていることを確認
      (let ((sym (find-symbol "*SERVER*" :voro)))
        (ok (and sym (boundp sym))
            "*server* should be defined and bound")))))

;;;
;;; stop テスト
;;; 注: stop は内部で nil チェックを行うため、DB/Redis 接続なしでも呼び出し可能。
;;;     with-test-environment を使用すると、stop 内の disconnect-* と
;;;     with-test-environment のクリーンアップで二重切断が発生するため使用しない。
;;;

(deftest test-stop-idempotent
  (with-clean-server-state
    (testing "stop の二重呼び出しは冪等"
      ;; サーバーが起動していない状態で stop を2回呼び出し
      (handler-case
          (progn
            (stop)
            (stop)
            (ok t "Double stop should not raise error"))
        (error (e)
          (declare (ignore e))
          (ok nil "Double stop raised an error"))))

    (testing "stop 後 *server* は NIL"
      (stop)
      (ok (null voro::*server*)
          "*server* should be NIL after stop"))))

;;;
;;; start/stop 統合テスト
;;; 注: ポートバインディングを伴うため、他のテストサーバーとの競合に注意
;;; 注: start は内部で connect-db/connect-redis を呼ぶため、with-test-environment は使用しない
;;;

(deftest test-start-stop-cycle
  ;; テスト環境の検証のみ（接続はstartに任せる）
  (verify-test-database)

  (with-clean-server-state
    (testing "start でサーバーが起動する"
      ;; 専用ポートで起動（start が DB/Redis 接続も行う）
      ;; テストではスレッドで起動してブロックを回避
      (start :port *test-main-port* :use-thread t)
      ;; サーバー起動を少し待つ
      (sleep 0.5)
      (ok (not (null voro::*server*))
          "*server* should be non-NIL after start"))

    (testing "stop でサーバーが停止する"
      (stop)
      (ok (null voro::*server*)
          "*server* should be NIL after stop"))))

;;;
;;; エラーハンドリングテスト
;;; 注: スタブ化によるテスト（実際の接続失敗を模擬）
;;; 注: with-test-environment を使用するが、connect-db/connect-redis をスタブ化して
;;;     即座にエラーを発生させるため、実際の二重接続は発生しない。
;;;     詳細はセクション2.2の注を参照。
;;;

(deftest test-start-db-failure-handling
  (with-test-environment
    (with-clean-server-state
      (testing "DB接続失敗時にエラーが再スローされ、stop が呼ばれる"
        ;; 一旦DB接続を切断
        (disconnect-db)
        ;; stop の呼び出しを追跡するフラグ
        (let ((stop-called nil)
              (original-connect-fn (symbol-function 'voro.db:connect-db))
              (original-stop-fn (symbol-function 'voro:stop)))
          (unwind-protect
              (progn
                ;; connect-db をスタブ化してエラーを発生させる
                (setf (symbol-function 'voro.db:connect-db)
                      (lambda () (error "Simulated DB connection failure")))
                ;; stop をスタブ化して呼び出しを追跡
                (setf (symbol-function 'voro:stop)
                      (lambda ()
                        (setf stop-called t)
                        (funcall original-stop-fn)))
                (handler-case
                    (progn
                      (start :port *test-main-port* :use-thread t)
                      (ok nil "start should have raised an error"))
                  (error (e)
                    (ok (search "Simulated DB" (princ-to-string e))
                        "Error message should contain the simulated error")
                    (ok stop-called
                        "stop should be called when start fails"))))
            ;; 元の関数を復元
            (setf (symbol-function 'voro.db:connect-db) original-connect-fn)
            (setf (symbol-function 'voro:stop) original-stop-fn)
            ;; DB接続を再確立
            (connect-db)))))))

(deftest test-start-redis-failure-handling
  (with-test-environment
    (with-clean-server-state
      (testing "Redis接続失敗時にエラーが再スローされ、stop が呼ばれる"
        ;; 一旦Redis接続を切断
        (disconnect-redis)
        ;; stop の呼び出しを追跡するフラグ
        (let ((stop-called nil)
              (original-connect-fn (symbol-function 'voro.redis:connect-redis))
              (original-stop-fn (symbol-function 'voro:stop)))
          (unwind-protect
              (progn
                ;; connect-redis をスタブ化してエラーを発生させる
                (setf (symbol-function 'voro.redis:connect-redis)
                      (lambda () (error "Simulated Redis connection failure")))
                ;; stop をスタブ化して呼び出しを追跡
                (setf (symbol-function 'voro:stop)
                      (lambda ()
                        (setf stop-called t)
                        (funcall original-stop-fn)))
                (handler-case
                    (progn
                      (start :port *test-main-port* :use-thread t)
                      (ok nil "start should have raised an error"))
                  (error (e)
                    (ok (search "Simulated Redis" (princ-to-string e))
                        "Error message should contain the simulated error")
                    (ok stop-called
                        "stop should be called when start fails"))))
            ;; 元の関数を復元
            (setf (symbol-function 'voro.redis:connect-redis) original-connect-fn)
            (setf (symbol-function 'voro:stop) original-stop-fn)
            ;; Redis接続を再確立
            (connect-redis)))))))

;;;
;;; clack:stop 失敗時のエラーハンドリングテスト
;;;

(deftest test-stop-clack-failure
  (with-clean-server-state
    (testing "clack:stop失敗時は*server*が保持されDB/Redisは切断されない"
      ;; *server*にダミー値を設定
      (let ((dummy-server (make-instance 'standard-object)))
        (setf voro::*server* dummy-server)
        (let ((original-fn (symbol-function 'clack:stop)))
          (unwind-protect
              (progn
                (setf (symbol-function 'clack:stop)
                      (lambda (server)
                        (declare (ignore server))
                        (error "Simulated clack:stop failure")))
                ;; stop 呼び出し
                (stop)
                ;; *server* は NIL にならない（サーバーが残存していることを示す）
                (ok (not (null voro::*server*))
                    "*server* should NOT be NIL when clack:stop fails")
                ;; 同じオブジェクトが保持されている
                (ok (eq voro::*server* dummy-server)
                    "*server* should retain the original server object"))
            ;; 元の関数を復元
            (setf (symbol-function 'clack:stop) original-fn)
            ;; クリーンアップ: *server* を NIL に戻す
            (setf voro::*server* nil)))))))
