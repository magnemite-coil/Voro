(defpackage voro.test.redis
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment)
  (:import-from :voro.redis
                :connect-redis
                :disconnect-redis
                :*redis-connection*
                :redis-health-check
                :ensure-redis-connected
                :red-set
                :red-get
                :red-del
                :red-expire
                :red-hset
                :red-hget
                :red-hgetall)
  (:import-from :voro.config
                :*redis-max-retries*
                :*redis-initial-retry-delay*
                :*redis-max-retry-delay*
                :*redis-health-check-enabled*))
(in-package :voro.test.redis)

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

(defmacro with-disconnected-redis (&body body)
  "一時的にRedis接続を切断してテストを実行
   テスト終了後は接続を復元する

   注意: このマクロは *redis-connection* を nil にするため、
   redis-health-check のエラーハンドリング回路をテストする場合は
   redis:red-ping をスタブ化する方法を使用すること

   エラー動作:
   - body 内で発生したエラーは unwind-protect により伝播する
   - エラー発生時も cleanup（再接続・タイムスタンプ復元）は実行される
   - 再接続失敗時はエラーを再シグナルする（テスト失敗として検出可能）"
  `(let ((original-connection *redis-connection*)
         (original-health-check-time voro.redis::*last-health-check-time*))
     (unwind-protect
          (progn
            (disconnect-redis)
            ,@body)
       ;; 元接続が存在し、かつ現在接続がない場合のみ再接続
       (when (and original-connection (null *redis-connection*))
         (connect-redis))  ; 再接続失敗時はエラーをそのまま伝播
       ;; タイムスタンプは常に復元
       (setf voro.redis::*last-health-check-time* original-health-check-time))))

;;;
;;; calculate-retry-delay テスト（内部関数）
;;;

(deftest test-calculate-retry-delay
  (with-config-override ((voro.config:*redis-initial-retry-delay* 1)
                         (voro.config:*redis-max-retry-delay* 30))
    (testing "エクスポネンシャルバックオフの計算"
      (ok (= (voro.redis::calculate-retry-delay 0) 1)
          "attempt=0 should return initial delay (1)")
      (ok (= (voro.redis::calculate-retry-delay 1) 2)
          "attempt=1 should return 2")
      (ok (= (voro.redis::calculate-retry-delay 2) 4)
          "attempt=2 should return 4")
      (ok (= (voro.redis::calculate-retry-delay 3) 8)
          "attempt=3 should return 8")
      (ok (= (voro.redis::calculate-retry-delay 4) 16)
          "attempt=4 should return 16"))
    (testing "上限キャップ"
      (ok (= (voro.redis::calculate-retry-delay 5) 30)
          "attempt=5 should be capped at max delay (30)")
      (ok (= (voro.redis::calculate-retry-delay 10) 30)
          "attempt=10 should be capped at max delay (30)"))))

;;;
;;; connect-redis テスト
;;;

(deftest test-connect-redis
  (testing "正常な接続"
    (with-test-environment
      ;; 一度切断してから再接続をテスト
      (disconnect-redis)
      (ok (null *redis-connection*)
          "Should be disconnected")
      (connect-redis)
      (ok (not (null *redis-connection*))
          "*redis-connection* should be set")
      (ok (string= (redis:red-ping) "PONG")
          "redis:red-ping should succeed"))))

(deftest test-connect-redis-retry-failure
  (testing "リトライ失敗時のエラーとリトライ回数検証"
    (with-config-override ((voro.config:*redis-max-retries* 2)
                           (voro.config:*redis-initial-retry-delay* 0)
                           (voro.config:*redis-max-retry-delay* 0))
      (let ((attempt-count 0)
            (original-fn (symbol-function 'voro.redis::try-connect-redis)))
        (unwind-protect
            (progn
              ;; カウンター付きスタブ
              (setf (symbol-function 'voro.redis::try-connect-redis)
                    (lambda ()
                      (incf attempt-count)
                      nil))
              (handler-case
                  (progn
                    (connect-redis)
                    (fail "connect-redis should have signaled an error"))
                (error (e)
                  ;; リトライ回数検証（無限ループ回帰検知）
                  (ok (= attempt-count 2)
                      (format nil "Should retry exactly 2 times (got ~A)" attempt-count))
                  ;; エラーメッセージ検証
                  (let ((msg (princ-to-string e)))
                    (ok (search "error_id" msg)
                        "Error should contain error_id"))
                  ;; 副作用検証
                  (ok (null *redis-connection*)
                      "*redis-connection* should be NIL after failure"))))
          ;; 元の関数を必ず復元
          (setf (symbol-function 'voro.redis::try-connect-redis) original-fn))))))

;;;
;;; disconnect-redis テスト
;;;

(deftest test-disconnect-redis
  (testing "正常な切断"
    (with-test-environment
      (ok (not (null *redis-connection*))
          "*redis-connection* should exist before disconnect")
      (disconnect-redis)
      (ok (null *redis-connection*)
          "*redis-connection* should be NIL after disconnect")))

  (testing "二重切断の冪等性"
    (with-test-environment
      (disconnect-redis)
      ;; 二重切断でエラーが発生しないこと
      (ok (null (disconnect-redis))
          "Double disconnect should not raise error")))

  (testing "切断処理エラー時の状態クリア"
    (with-test-environment
      ;; 接続確認
      (ok (not (null *redis-connection*)))
      ;; redis:disconnect をスタブ化してエラーを発生させる
      (let ((original-fn (symbol-function 'redis:disconnect)))
        (unwind-protect
            (progn
              (setf (symbol-function 'redis:disconnect)
                    (lambda () (error "Simulated disconnect error")))
              ;; 切断実行（エラーは抑制される）
              (disconnect-redis)
              ;; エラーが発生しても *redis-connection* は NIL になる
              (ok (null *redis-connection*)
                  "*redis-connection* should be NIL even when redis:disconnect fails"))
          ;; 元の関数を復元
          (setf (symbol-function 'redis:disconnect) original-fn)
          ;; cl-redis の内部接続状態をクリア（スタブ化でスキップされたため）
          (handler-case
              (redis:disconnect)
            (error () nil)))))))

;;;
;;; redis-health-check テスト
;;;

(deftest test-redis-health-check-disabled
  (testing "ヘルスチェック無効時の動作"
    (with-test-environment
      (with-config-override ((voro.config:*redis-health-check-enabled* nil))
        (testing "接続あり → T を返す"
          (ok (not (null *redis-connection*))
              "Should have connection")
          (ok (redis-health-check)
              "Health check should return T when connected"))
        (testing "接続なし → NIL を返す"
          (with-disconnected-redis
            (ok (null (redis-health-check))
                "Health check should return NIL when disconnected")))))))

(deftest test-redis-health-check-enabled
  (testing "ヘルスチェック有効時の動作"
    (with-test-environment
      (with-config-override ((voro.config:*redis-health-check-enabled* t))
        ;; タイムスタンプを保存・復元してテスト間の順序依存を防止
        (let ((original-time voro.redis::*last-health-check-time*))
          (unwind-protect
              (progn
                ;; タイムスタンプをリセットしてチェックを強制実行
                (setf voro.redis::*last-health-check-time* 0)
                (ok (redis-health-check)
                    "Health check should return T when ping succeeds"))
            ;; 元の値を復元
            (setf voro.redis::*last-health-check-time* original-time)))))))

(deftest test-redis-health-check-cache
  (testing "キャッシュ動作の検証"
    (with-test-environment
      (with-config-override ((voro.config:*redis-health-check-enabled* t))
        ;; キャッシュ間隔を明示的に固定（テストの安定性確保）
        ;; let バインディングでスコープ終了時に自動復元
        (let ((voro.redis::*health-check-interval* 60)
              (original-time voro.redis::*last-health-check-time*))
          (unwind-protect
              (progn
                ;; タイムスタンプをリセット
                (setf voro.redis::*last-health-check-time* 0)
                (let ((time-before (get-universal-time)))
                  ;; 1回目: 実際にPINGが実行され、タイムスタンプが更新される
                  (redis-health-check)
                  (ok (>= voro.redis::*last-health-check-time* time-before)
                      "Timestamp should be updated after health check"))
                ;; 2回目のチェック（間隔内）
                (let ((cached-time voro.redis::*last-health-check-time*))
                  ;; 2回目: キャッシュによりタイムスタンプは変わらない
                  (redis-health-check)
                  (ok (= voro.redis::*last-health-check-time* cached-time)
                      "Timestamp should not change within interval")))
            ;; タイムスタンプを復元（テスト間の順序依存・フレーク防止）
            (setf voro.redis::*last-health-check-time* original-time)))))))

(deftest test-redis-health-check-failure
  (testing "ヘルスチェック失敗時の動作"
    (with-test-environment
      (with-config-override ((voro.config:*redis-health-check-enabled* t))
        (let ((original-ping (symbol-function 'redis:red-ping))
              (original-time voro.redis::*last-health-check-time*))
          (unwind-protect
              (progn
                ;; redis:red-ping をスタブ化してエラーを投げる
                (setf (symbol-function 'redis:red-ping)
                      (lambda () (error "Simulated connection failure")))
                ;; タイムスタンプをリセットしてキャッシュをバイパス
                (setf voro.redis::*last-health-check-time* 0)
                ;; ヘルスチェック失敗 → NIL
                (ok (null (redis-health-check))
                    "Health check should return NIL when ping fails")
                ;; エラーハンドリングで *redis-connection* が nil にクリア
                (ok (null *redis-connection*)
                    "*redis-connection* should be NIL after health check failure"))
            ;; 元の関数とタイムスタンプを復元
            (setf (symbol-function 'redis:red-ping) original-ping)
            (setf voro.redis::*last-health-check-time* original-time)
            ;; cl-redis の内部接続状態をクリア（redis-health-check ではクリアされない）
            (handler-case
                (redis:disconnect)
              (error () nil))
            ;; 接続を再確立（後続テストのため）
            (when (null *redis-connection*)
              (connect-redis))))))))

;;;
;;; ensure-redis-connected テスト
;;;

(deftest test-ensure-redis-connected
  (testing "接続済みの場合"
    (with-test-environment
      (ok (not (null *redis-connection*))
          "Should have connection")
      (ok (null (ensure-redis-connected))
          "Should return NIL when already connected")))

  (testing "未接続時の再接続"
    (with-test-environment
      (with-disconnected-redis
        (ok (null *redis-connection*)
            "Should have no connection")
        (ok (ensure-redis-connected)
            "Should return T when reconnected")
        (ok (not (null *redis-connection*))
            "*redis-connection* should be restored")))))

(deftest test-ensure-redis-connected-recovery
  (testing "ヘルスチェック失敗後の再接続"
    (with-test-environment
      (with-config-override ((voro.config:*redis-health-check-enabled* t))
        ;; 接続確認
        (ok (not (null *redis-connection*))
            "Should have connection before test")
        ;; redis:red-ping をスタブ化してヘルスチェックを失敗させる
        (let ((original-ping (symbol-function 'redis:red-ping))
              (original-time voro.redis::*last-health-check-time*))
          (unwind-protect
              (progn
                (setf (symbol-function 'redis:red-ping)
                      (lambda () (error "Simulated connection failure")))
                ;; タイムスタンプをリセット
                (setf voro.redis::*last-health-check-time* 0)
                ;; ヘルスチェック失敗で *redis-connection* が NIL になる
                (redis-health-check)
                (ok (null *redis-connection*)
                    "*redis-connection* should be NIL after health check failure")
                ;; スタブを解除（再接続前に元に戻す）
                (setf (symbol-function 'redis:red-ping) original-ping)
                ;; cl-redis の内部接続状態をクリア（redis-health-check ではクリアされない）
                (handler-case
                    (redis:disconnect)
                  (error () nil))
                ;; ensure-redis-connected で再接続
                (ensure-redis-connected)
                ;; 再接続後は接続が確立されていることを確認
                (ok (not (null *redis-connection*))
                    "*redis-connection* should be restored after ensure-redis-connected"))
            ;; 確実に元の関数を復元
            (setf (symbol-function 'redis:red-ping) original-ping)
            (setf voro.redis::*last-health-check-time* original-time)))
        (ok (not (null *redis-connection*)))))))

;;;
;;; Redis コマンドラッパーテスト
;;;

(deftest test-red-set-get
  (with-test-environment
    (testing "red-set/red-get の基本動作"
      (red-set "test-key" "test-value")
      (ok (string= (red-get "test-key") "test-value")
          "Should get the value that was set"))
    (testing "値の上書き"
      (red-set "test-overwrite-key" "original")
      (ok (string= (red-get "test-overwrite-key") "original")
          "Should get original value")
      (red-set "test-overwrite-key" "updated")
      (ok (string= (red-get "test-overwrite-key") "updated")
          "Should get updated value after overwrite"))
    (testing "存在しないキー"
      (ok (null (red-get "nonexistent-key"))
          "Should return NIL for nonexistent key"))))

(deftest test-red-del
  (with-test-environment
    (testing "キーの削除"
      (red-set "test-del-key" "value")
      (ok (string= (red-get "test-del-key") "value")
          "Key should exist before deletion")
      (red-del "test-del-key")
      (ok (null (red-get "test-del-key"))
          "Key should be deleted"))
    (testing "存在しないキーの削除（冪等性）"
      ;; 存在しないキーを削除してもエラーにならないことを確認
      (ok (null (red-get "nonexistent-del-key"))
          "Key should not exist before test")
      (red-del "nonexistent-del-key")  ; エラーが発生しなければOK
      (ok t "Deleting nonexistent key should not raise error"))))

(deftest test-red-expire
  (with-test-environment
    (testing "TTL設定と確認"
      (red-set "test-expire-key" "value")
      (red-expire "test-expire-key" 3600)
      (let ((ttl (redis:red-ttl "test-expire-key")))
        (ok (and (> ttl 0) (<= ttl 3600))
            "TTL should be set and within range")))

    (testing "TTLの減少確認"
      (red-set "test-expire-decay-key" "value")
      (red-expire "test-expire-decay-key" 10)
      (let ((ttl-before (redis:red-ttl "test-expire-decay-key")))
        ;; 1秒待機
        (sleep 1)
        (let ((ttl-after (redis:red-ttl "test-expire-decay-key")))
          (ok (< ttl-after ttl-before)
              "TTL should decrease over time"))))

    (testing "期限切れ後のキー消失"
      (red-set "test-expire-short-key" "value")
      (red-expire "test-expire-short-key" 1)
      ;; 2秒待機（TTL=1秒より長く）
      (sleep 2)
      (ok (null (red-get "test-expire-short-key"))
          "Key should be NIL after expiration"))))

(deftest test-red-hash-commands
  (with-test-environment
    (testing "red-hset/red-hget"
      (red-hset "test-hash" "field1" "value1")
      (ok (string= (red-hget "test-hash" "field1") "value1")
          "Should get the field value"))
    (testing "red-hgetall"
      (red-hset "test-hash" "field2" "value2")
      (let ((all-fields (red-hgetall "test-hash")))
        (ok (listp all-fields)
            "Should return a list")
        (ok (= (length all-fields) 4)
            "Should contain exactly 4 elements (2 field-value pairs)")
        ;; フィールド名の存在確認
        (ok (member "field1" all-fields :test #'string=)
            "Should contain field1")
        (ok (member "field2" all-fields :test #'string=)
            "Should contain field2")
        ;; フィールドと値のペア検証（位置は不定のためヘルパー関数で確認）
        (let ((hash-table (make-hash-table :test #'equal)))
          ;; フラットリストをハッシュテーブルに変換
          (loop for (k v) on all-fields by #'cddr
                do (setf (gethash k hash-table) v))
          (ok (string= (gethash "field1" hash-table) "value1")
              "field1 should have value1")
          (ok (string= (gethash "field2" hash-table) "value2")
              "field2 should have value2"))))
    (testing "存在しないフィールド"
      (ok (null (red-hget "test-hash" "nonexistent"))
          "Should return NIL for nonexistent field"))))

(deftest test-red-commands-auto-reconnect
  (with-test-environment
    (testing "red-set による自動再接続"
      ;; 接続を切断
      (disconnect-redis)
      (ok (null *redis-connection*))
      ;; コマンドラッパー経由で自動再接続
      (red-set "test-reconnect-key" "test-value")
      ;; 再接続されたことを確認
      (ok (not (null *redis-connection*)))
      ;; 値が設定されたことを確認
      (ok (string= (red-get "test-reconnect-key") "test-value")))

    (testing "red-hset による自動再接続"
      ;; 再度切断
      (disconnect-redis)
      (ok (null *redis-connection*))
      ;; ハッシュコマンドでも自動再接続が動作することを確認
      (red-hset "test-reconnect-hash" "field" "value")
      ;; 再接続されたことを確認
      (ok (not (null *redis-connection*)))
      ;; 値が設定されたことを確認
      (ok (string= (red-hget "test-reconnect-hash" "field") "value")))))

;;;
;;; 切断失敗時のエラーハンドリングテスト
;;;

(deftest test-try-connect-redis-disconnect-failure
  (testing "既存接続の切断失敗時も新規接続を試行する"
    (with-test-environment
      (ok (not (null *redis-connection*)))
      ;; cl-redis 内部状態を事前にクリア（スタブ化後の redis:connect を成功させるため）
      ;; ただし *redis-connection* は復元して「接続がある」状態を維持
      (let ((saved-connection *redis-connection*))
        (redis:disconnect)
        (setf *redis-connection* saved-connection))
      (let ((original-fn (symbol-function 'redis:disconnect))
            (disconnect-called nil))
        (unwind-protect
            (progn
              (setf (symbol-function 'redis:disconnect)
                    (lambda ()
                      (setf disconnect-called t)
                      (error "Simulated Redis disconnect failure")))
              ;; try-connect-redis を呼び出し
              ;; *redis-connection* が非 nil なので、まず redis:disconnect が呼ばれ（スタブがエラーを投げる）
              ;; その後、新規接続が試行される
              (ok (voro.redis::try-connect-redis)
                  "try-connect-redis should succeed despite disconnect failure")
              (ok disconnect-called
                  "redis:disconnect should have been called"))
          ;; 元の関数を復元
          (setf (symbol-function 'redis:disconnect) original-fn)
          ;; cl-redis内部状態のクリーンアップ
          (handler-case (redis:disconnect) (error () nil)))))))

;;;
;;; try-connect-redis エラーパステスト
;;;

(deftest test-try-connect-redis-connection-failure
  (testing "redis:connect 失敗時は NIL を返す"
    (with-test-environment
      ;; 事前に接続を切断（*redis-connection* を NIL に）
      (disconnect-redis)
      (ok (null *redis-connection*)
          "Should start with no connection")

      (let ((original-fn (symbol-function 'redis:connect)))
        (unwind-protect
            (progn
              ;; redis:connect をスタブ化してエラーを発生
              (setf (symbol-function 'redis:connect)
                    (lambda (&rest args)
                      (declare (ignore args))
                      (error "Simulated Redis connection failure")))

              ;; try-connect-redis を呼び出し
              (let ((result (voro.redis::try-connect-redis)))
                ;; 戻り値が NIL であることを確認
                (ok (null result)
                    "try-connect-redis should return NIL on connection failure")
                ;; 接続失敗なので *redis-connection* は NIL のまま
                (ok (null *redis-connection*)
                    "*redis-connection* should remain NIL on connection failure")))

          ;; 元の関数を復元
          (setf (symbol-function 'redis:connect) original-fn)
          ;; 注: with-test-environment の teardown は disconnect のみ行い、
          ;; 次の with-test-environment の setup で再接続される。
          ;; 条件付き再接続: *redis-connection* が NIL の場合のみ再接続し、
          ;; ログノイズを削減する。
          (unless *redis-connection*
            (handler-case (connect-redis) (error () nil))))))))

(deftest test-try-connect-redis-select-failure
  (testing "redis:red-select 失敗時は NIL を返し、接続をクリアする"
    (with-test-environment
      ;; 事前に接続を切断
      (disconnect-redis)
      (ok (null *redis-connection*))

      (let ((original-select-fn (symbol-function 'redis:red-select)))
        (unwind-protect
            (progn
              ;; redis:red-select をスタブ化してエラーを発生
              (setf (symbol-function 'redis:red-select)
                    (lambda (db)
                      (declare (ignore db))
                      (error "Simulated Redis SELECT failure")))

              ;; try-connect-redis を呼び出し
              (let ((result (voro.redis::try-connect-redis)))
                (ok (null result)
                    "try-connect-redis should return NIL on SELECT failure")
                ;; 実装変更により、エラーハンドラで接続がクリアされる
                (ok (null *redis-connection*)
                    "*redis-connection* should be cleared after SELECT failure")))

          ;; cleanup: スタブを解除して再接続
          ;; 実装変更により、try-connect-redis のエラーハンドラが disconnect-redis を
          ;; 呼び出すため、*redis-connection* と cl-redis 内部状態の両方がクリア済み。
          ;; したがって、追加の redis:disconnect 呼び出しは不要。
          (setf (symbol-function 'redis:red-select) original-select-fn)
          ;; 条件付き再接続: *redis-connection* が NIL の場合のみ。
          ;; with-test-environment の teardown との二重再接続を避け、
          ;; ログノイズを削減する。
          (unless *redis-connection*
            (handler-case (connect-redis) (error () nil))))))))

(deftest test-connect-redis-retry-with-connection-failures
  (testing "リトライ中の接続失敗と最終的な成功"
    (with-config-override ((voro.config:*redis-max-retries* 3)
                           (voro.config:*redis-initial-retry-delay* 0)
                           (voro.config:*redis-max-retry-delay* 0))
      (with-test-environment
        ;; 事前に接続を切断
        (disconnect-redis)

        (let ((original-fn (symbol-function 'redis:connect))
              (attempt-count 0))
          (unwind-protect
              (progn
                ;; redis:connect をスタブ化: 最初の2回は失敗、3回目で成功
                ;;
                ;; 技術的注記: original-fn はこの let スコープでレキシカルに
                ;; キャプチャされるため、unwind-protect の cleanup で
                ;; symbol-function を復元した後でも、スタブのラムダ内部から
                ;; 正しく元の関数を呼び出せる（クロージャの特性）
                (setf (symbol-function 'redis:connect)
                      (lambda (&rest args)
                        (incf attempt-count)
                        (if (<= attempt-count 2)
                            (error "Simulated failure (attempt ~A)" attempt-count)
                            ;; 3回目は元の関数を呼び出す（クロージャでキャプチャ済み）
                            (apply original-fn args))))

                ;; connect-redis を呼び出し（成功するまでリトライ）
                (connect-redis)

                ;; 3回試行されたことを確認
                (ok (= attempt-count 3)
                    (format nil "Should have attempted 3 times (got ~A)" attempt-count))

                ;; 最終的に接続成功
                (ok (not (null *redis-connection*))
                    "*redis-connection* should be set after successful retry"))

            ;; 元の関数を復元
            (setf (symbol-function 'redis:connect) original-fn)
            ;; 注: このテストでは3回目で接続成功するため *redis-connection* は設定済み。
            ;; 条件付き再接続: *redis-connection* が NIL の場合のみ再接続。
            ;; 通常は実行されないが、以下の理由で残す:
            ;; 1. テストケース1・2との cleanup パターンの一貫性
            ;; 2. 万が一テスト失敗した場合でも後続テストに影響しない防御的措置
            ;; 3. 将来のテスト変更時に cleanup 漏れを防ぐ安全策
            (unless *redis-connection*
              (handler-case (connect-redis) (error () nil)))))))))
