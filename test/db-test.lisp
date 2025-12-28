(defpackage voro.test.db
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment)
  (:import-from :voro.db
                :connect-db
                :disconnect-db
                :*db-connection*
                :db-health-check
                :ensure-db-connected)
  (:import-from :voro.config
                :*db-max-retries*
                :*db-initial-retry-delay*
                :*db-max-retry-delay*
                :*db-health-check-enabled*))
(in-package :voro.test.db)

;;;
;;; ヘルパーマクロ
;;;

(defmacro with-config-override ((&rest bindings) &body body)
  "一時的に設定値を上書きしてテストを実行"
  (let ((original-vars (mapcar (lambda (b) (gensym)) bindings)))
    `(let (,@(mapcar (lambda (orig b) `(,orig ,(car b)))
                     original-vars bindings))
       (unwind-protect
            (progn
              ,@(mapcar (lambda (b) `(setf ,(car b) ,(cadr b))) bindings)
              ,@body)
         ,@(mapcar (lambda (orig b) `(setf ,(car b) ,orig))
                   original-vars bindings)))))

(defmacro with-disconnected-db (&body body)
  "一時的にDB接続を切断してテストを実行
   テスト終了後は接続を復元する
   タイムスタンプは常に元の値に復元する（フレーク防止）
   元接続が無かったケースでは再接続しない（副作用防止）"
  `(let ((original-connection *db-connection*)
         (original-mito-connection mito.connection:*connection*)
         (original-health-check-time voro.db::*last-health-check-time*))
     (declare (ignore original-mito-connection))
     (unwind-protect
          (progn
            (disconnect-db)
            ,@body)
       ;; 元接続が存在し、かつ現在接続がない場合のみ再接続
       (when (and original-connection (null *db-connection*))
         (handler-case
             (connect-db)
           (error (e)
             (declare (ignore e))
             ;; 再接続失敗時は nil のままにする
             ;; 注意: original-connection は disconnect-db で既に切断済みの
             ;; 「死んだ接続オブジェクト」なので復元しない
             nil)))
       ;; タイムスタンプは常に復元（テスト間の順序依存・フレーク防止）
       (setf voro.db::*last-health-check-time* original-health-check-time))))

;;;
;;; calculate-retry-delay テスト（内部関数）
;;;

(deftest test-calculate-retry-delay
  (testing "エクスポネンシャルバックオフの計算"
    (with-config-override ((voro.config:*db-initial-retry-delay* 1)
                           (voro.config:*db-max-retry-delay* 30))
      (ok (= (voro.db::calculate-retry-delay 0) 1)
          "attempt=0 should return 1 second")
      (ok (= (voro.db::calculate-retry-delay 1) 2)
          "attempt=1 should return 2 seconds")
      (ok (= (voro.db::calculate-retry-delay 2) 4)
          "attempt=2 should return 4 seconds")
      (ok (= (voro.db::calculate-retry-delay 3) 8)
          "attempt=3 should return 8 seconds")
      (ok (= (voro.db::calculate-retry-delay 4) 16)
          "attempt=4 should return 16 seconds")
      (ok (= (voro.db::calculate-retry-delay 5) 30)
          "attempt=5 should be capped at max-retry-delay")
      (ok (= (voro.db::calculate-retry-delay 10) 30)
          "attempt=10 should be capped at max-retry-delay"))))

;;;
;;; build-connection-string テスト（内部関数）
;;;

(deftest test-build-connection-string
  (testing "接続文字列の構築"
    (with-config-override ((voro.config:*db-host* "testhost")
                           (voro.config:*db-port* 5432)
                           (voro.config:*db-name* "testdb")
                           (voro.config:*db-user* "testuser")
                           (voro.config:*db-password* "testpass"))
      (let ((conn-str (voro.db::build-connection-string))
            (expected "postgres://testuser:testpass@testhost:5432/testdb"))
        (ok (equal conn-str expected)
            "Connection string should match expected format exactly"))))

  (testing "URI予約文字を含むパスワード（現在の挙動を明示）"
    (with-config-override ((voro.config:*db-host* "testhost")
                           (voro.config:*db-port* 5432)
                           (voro.config:*db-name* "testdb")
                           (voro.config:*db-user* "testuser")
                           (voro.config:*db-password* "pass@word:123"))
      (let ((conn-str (voro.db::build-connection-string))
            ;; 予約文字を含む完全な想定文字列で検証（ホスト/ポート欠落を検知）
            (expected "postgres://testuser:pass@word:123@testhost:5432/testdb"))
        ;; 現在の実装はエンコードしない（完全一致で厳密に検証）
        (ok (equal conn-str expected)
            "Password with reserved chars is NOT URL-encoded (current behavior)")))))

;;;
;;; connect-db テスト
;;;

(deftest test-connect-db
  (testing "正常な接続"
    (with-test-environment
      ;; with-test-environment が既に接続を確立しているので切断
      (disconnect-db)
      (ok (null *db-connection*)
          "*db-connection* should be NIL before connect-db test")
      ;; connect-db のテスト
      (ok (connect-db)
          "connect-db should return T on success")
      (ok (not (null *db-connection*))
          "*db-connection* should be set after connect-db")
      (ok (not (null mito.connection:*connection*))
          "mito.connection:*connection* should be set after connect-db"))))

(deftest test-connect-db-retry-failure
  (testing "リトライ失敗時のエラーとリトライ回数検証"
    ;; 初期状態をクリア（前のテストで残った接続を除去）
    (disconnect-db)
    (with-config-override ((voro.config:*db-max-retries* 2)
                           (voro.config:*db-initial-retry-delay* 0)
                           (voro.config:*db-max-retry-delay* 0))
      (let ((attempt-count 0)
            (original-fn (symbol-function 'voro.db::try-connect-db)))
        (unwind-protect
            (progn
              ;; symbol-function を差し替えてスタブ化
              (setf (symbol-function 'voro.db::try-connect-db)
                    (lambda ()
                      (incf attempt-count)
                      nil))
              (handler-case
                  (progn
                    (connect-db)
                    (fail "connect-db should have signaled an error"))
                (error (e)
                  ;; リトライ回数検証（無限ループ回帰検知）
                  (ok (= attempt-count 2)
                      (format nil "Should retry exactly 2 times (got ~A)" attempt-count))
                  ;; エラーメッセージ検証
                  (let ((msg (princ-to-string e)))
                    (ok (search "error_id" msg)
                        "Error should contain error_id"))
                  ;; 副作用検証
                  (ok (null *db-connection*)
                      "*db-connection* should be NIL after failure"))))
          ;; 元の関数を必ず復元
          (setf (symbol-function 'voro.db::try-connect-db) original-fn))))))

;;;
;;; disconnect-db テスト
;;;

(deftest test-disconnect-db
  (testing "正常な切断"
    (with-test-environment
      (ok (not (null *db-connection*))
          "*db-connection* should exist before disconnect")
      (ok (not (null mito.connection:*connection*))
          "mito.connection:*connection* should exist before disconnect")
      (disconnect-db)
      (ok (null *db-connection*)
          "*db-connection* should be NIL after disconnect")
      (ok (null mito.connection:*connection*)
          "mito.connection:*connection* should be NIL after disconnect")))

  (testing "二重切断の冪等性"
    (with-test-environment
      (disconnect-db)
      ;; 二重切断でエラーが発生しないこと
      (ok (null (disconnect-db))
          "Double disconnect should not raise error")))

  (testing "切断処理エラー時の状態クリア"
    (with-test-environment
      ;; 接続確認
      (ok (not (null *db-connection*)))
      ;; mito:disconnect-toplevel をスタブ化してエラーを発生させる
      (let ((original-fn (symbol-function 'mito:disconnect-toplevel)))
        (unwind-protect
            (progn
              (setf (symbol-function 'mito:disconnect-toplevel)
                    (lambda () (error "Simulated disconnect error")))
              ;; 切断実行（エラーは抑制される）
              (disconnect-db)
              ;; エラーが発生しても *db-connection* は NIL になる
              (ok (null *db-connection*)
                  "*db-connection* should be NIL even when disconnect-toplevel fails"))
          ;; 元の関数を復元
          (setf (symbol-function 'mito:disconnect-toplevel) original-fn))))))

;;;
;;; db-health-check テスト
;;;

(deftest test-db-health-check-disabled
  (testing "ヘルスチェック無効時の動作"
    (with-test-environment
      (with-config-override ((voro.config:*db-health-check-enabled* nil))
        (ok (db-health-check)
            "Health check should return T when connection exists (disabled mode)")
        (disconnect-db)
        (ok (null (db-health-check))
            "Health check should return NIL when no connection (disabled mode)")))))

(deftest test-db-health-check-enabled
  (testing "ヘルスチェック有効時の動作"
    (with-test-environment
      (with-config-override ((voro.config:*db-health-check-enabled* t))
        ;; タイムスタンプを保存・復元してテスト間の順序依存を防止
        (let ((original-time voro.db::*last-health-check-time*))
          (unwind-protect
              (progn
                ;; タイムスタンプをリセットしてチェックを強制実行
                (setf voro.db::*last-health-check-time* 0)
                (ok (db-health-check)
                    "Health check should return T when query succeeds"))
            ;; 元の値を復元
            (setf voro.db::*last-health-check-time* original-time)))))))

(deftest test-db-health-check-cache
  (testing "キャッシュ動作の検証"
    (with-test-environment
      (with-config-override ((voro.config:*db-health-check-enabled* t))
        ;; キャッシュ間隔を明示的に固定（テストの安定性確保）
        (let ((voro.db::*health-check-interval* 60))
          ;; タイムスタンプをリセット
          (setf voro.db::*last-health-check-time* 0)
          (let ((time-before (get-universal-time)))
            (db-health-check)
            (ok (>= voro.db::*last-health-check-time* time-before)
                "Timestamp should be updated after health check"))
          ;; 2回目のチェック（間隔内）
          (let ((cached-time voro.db::*last-health-check-time*))
            (db-health-check)
            (ok (= voro.db::*last-health-check-time* cached-time)
                "Timestamp should not change within interval")))))))

(deftest test-db-health-check-failure
  (testing "クエリ失敗時の動作"
    (with-test-environment
      (with-config-override ((voro.config:*db-health-check-enabled* t))
        ;; 接続確認
        (ok (not (null *db-connection*)))
        ;; 意図的に接続を壊す（dbi:disconnect を直接呼ぶ）
        (dbi:disconnect *db-connection*)
        ;; タイムスタンプをリセットしてヘルスチェックを強制実行
        (setf voro.db::*last-health-check-time* 0)
        ;; ヘルスチェック実行（失敗するはず）
        (ok (null (db-health-check))
            "Health check should return NIL for broken connection")
        ;; *db-connection* が NIL になることを確認
        (ok (null *db-connection*)
            "*db-connection* should be NIL after failed health check")))))

(deftest test-db-health-check-failure-mito-state
  (testing "ヘルスチェック失敗時のmito接続状態（修正後の動作を検証）"
    (with-test-environment
      (with-config-override ((voro.config:*db-health-check-enabled* t))
        (ok (not (null *db-connection*)))
        (ok (not (null mito.connection:*connection*))
            "mito connection should exist before test")
        ;; 意図的に接続を壊す
        (dbi:disconnect *db-connection*)
        (setf voro.db::*last-health-check-time* 0)
        ;; ヘルスチェック実行
        (db-health-check)
        ;; *db-connection* は NIL になる
        (ok (null *db-connection*)
            "*db-connection* should be NIL after failed health check")
        ;; mito 接続もクリアされる（修正後の動作）
        (ok (null mito.connection:*connection*)
            "mito connection should be cleared after failed health check")))))

;;;
;;; ensure-db-connected テスト
;;;

(deftest test-ensure-db-connected
  (testing "接続済みの場合"
    (with-test-environment
      (ok (null (ensure-db-connected))
          "Should return NIL when already connected (unless skips)")))

  (testing "未接続時の再接続"
    (with-test-environment
      (with-disconnected-db
        (ok (ensure-db-connected)
            "Should return T when reconnecting (connect-db result)")
        (ok (not (null *db-connection*))
            "*db-connection* should be restored")))))

(deftest test-ensure-db-connected-recovery
  (testing "ヘルスチェック失敗後の再接続"
    (with-test-environment
      (with-config-override ((voro.config:*db-health-check-enabled* t))
        ;; 接続確認
        (ok (not (null *db-connection*)))
        ;; 意図的に接続を壊す
        (dbi:disconnect *db-connection*)
        ;; タイムスタンプをリセット
        (setf voro.db::*last-health-check-time* 0)
        ;; ヘルスチェック失敗で *db-connection* が NIL になる
        (db-health-check)
        (ok (null *db-connection*)
            "*db-connection* should be NIL after failed health check")
        ;; ensure-db-connected で再接続
        (ensure-db-connected)
        ;; 再接続後は接続が確立されていることを確認
        (ok (not (null *db-connection*))
            "*db-connection* should be restored after ensure-db-connected")
        (ok (not (null mito.connection:*connection*))
            "mito.connection:*connection* should be restored")))))

;;;
;;; 切断失敗時のエラーハンドリングテスト
;;;

(deftest test-try-connect-db-disconnect-failure
  (testing "既存接続の切断失敗時も新規接続を試行する"
    (with-test-environment
      ;; 接続確認
      (ok (not (null *db-connection*)))
      ;; dbi:disconnect をスタブ化
      (let ((original-fn (symbol-function 'dbi:disconnect))
            (disconnect-called nil))
        (unwind-protect
            (progn
              (setf (symbol-function 'dbi:disconnect)
                    (lambda (conn)
                      (declare (ignore conn))
                      (setf disconnect-called t)
                      (error "Simulated disconnect failure")))
              ;; try-connect-db を呼び出し
              ;; 注意: 旧接続はスタブ化によりリークするが、テスト環境内で許容される
              ;; （詳細は設計書「コネクションリーク対策」セクション参照）
              (ok (voro.db::try-connect-db)
                  "try-connect-db should succeed despite disconnect failure")
              (ok disconnect-called
                  "dbi:disconnect should have been called"))
          ;; 元の関数を復元
          (setf (symbol-function 'dbi:disconnect) original-fn))))))

(deftest test-db-health-check-mito-disconnect-failure
  (testing "ヘルスチェック失敗時のmito切断失敗は抑制される"
    (with-test-environment
      (with-config-override ((voro.config:*db-health-check-enabled* t))
        (ok (not (null *db-connection*)))
        ;; 接続を壊す
        (dbi:disconnect *db-connection*)
        ;; mito:disconnect-toplevel をスタブ化
        (let ((original-fn (symbol-function 'mito:disconnect-toplevel))
              (original-time voro.db::*last-health-check-time*)
              (disconnect-called nil))
          (unwind-protect
              (progn
                (setf (symbol-function 'mito:disconnect-toplevel)
                      (lambda ()
                        (setf disconnect-called t)
                        (error "Simulated mito disconnect failure")))
                ;; タイムスタンプをリセット
                (setf voro.db::*last-health-check-time* 0)
                ;; ヘルスチェック実行
                (ok (null (db-health-check))
                    "Health check should return NIL")
                (ok disconnect-called
                    "mito:disconnect-toplevel should have been called")
                ;; *db-connection* が NIL になることを確認
                (ok (null *db-connection*)
                    "*db-connection* should be NIL"))
            ;; 元の関数とタイムスタンプを復元
            (setf (symbol-function 'mito:disconnect-toplevel) original-fn)
            (setf voro.db::*last-health-check-time* original-time)
            ;; 重要: スタブ復元後に mito 接続を明示的に切断
            ;; （*db-connection* が NIL のため teardown では切断されない）
            (handler-case (mito:disconnect-toplevel) (error () nil))))))))
