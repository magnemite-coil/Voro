;;;
;;; PoC: HTTPサーバー起動テスト
;;;
;;; 目的: Clack + Woo によるHTTPサーバー起動・停止が安定して動作するかを検証
;;;

;; システムをロード
(ql:quickload :voro :silent t)
(ql:quickload :dexador :silent t)

(defpackage voro.poc.http-server
  (:use :cl)
  (:import-from :voro.web
                :*app*)
  (:import-from :voro.util.log
                :log-info
                :log-error
                :log-warn)
  (:import-from :clack)
  (:import-from :dexador)
  (:export :run-all-tests
           :main))

(in-package :voro.poc.http-server)

;;;
;;; 定数
;;;

(defparameter *test-server-port* 18080
  "テスト用HTTPサーバーのポート番号")

;;;
;;; ユーティリティ関数
;;;

(defun start-test-server ()
  "テスト用HTTPサーバーを起動
   戻り値: サーバーハンドラー"
  (log-info "Starting test HTTP server"
            :context (list :|port| *test-server-port*))
  (clack:clackup *app*
                 :server :woo
                 :port *test-server-port*
                 :use-default-middlewares nil
                 :debug nil
                 :silent t))

(defun stop-test-server (server)
  "テスト用HTTPサーバーを停止
   引数: server - サーバーハンドラー"
  (when server
    (log-info "Stopping test HTTP server"
              :context (list :|port| *test-server-port*))
    (clack:stop server)))

(defun verify-health-check (port &optional (max-retries 10))
  "HTTPサーバーのヘルスチェック（リトライ付き）

   引数:
     port: ポート番号
     max-retries: 最大リトライ回数（デフォルト: 10回、合計5秒）

   戻り値: サーバー起動成功時T、タイムアウト時NIL"
  (log-info "Performing health check"
            :context (list :|port| port
                           :|max_retries| max-retries))
  (loop repeat max-retries
        do (handler-case
               (multiple-value-bind (body status)
                   (dex:get (format nil "http://localhost:~D/" port)
                            :connect-timeout 1)
                 (declare (ignore body))
                 ;; サーバーが応答していれば成功（200でも404でも可）
                 (when (or (= status 200) (= status 404))
                   (log-info "Health check passed"
                             :context (list :|port| port
                                            :|status| status))
                   (return t)))
             (dex:http-request-not-found (e)
               ;; 404エラーはサーバーが起動している証拠
               (declare (ignore e))
               (log-info "Health check passed (404 response)"
                         :context (list :|port| port
                                        :|status| 404))
               (return t))
             (error (e)
               ;; 接続エラーなどはリトライ
               (log-info "Health check attempt failed, retrying..."
                         :context (list :|error| (type-of e)
                                        :|port| port))
               (sleep 0.5)))
        finally (progn
                  (log-warn "Health check failed after all retries"
                            :context (list :|port| port
                                           :|max_retries| max-retries))
                  (return nil))))

;;;
;;; 検証関数
;;;

(defun verify-server-start-stop ()
  "HTTPサーバーの起動・停止を検証

   検証内容:
     1. Wooサーバーを起動（ポート18080）
     2. ヘルスチェック（GET /）
     3. サーバーを停止

   戻り値: 成功時T、失敗時NIL"
  (let ((server nil))
    (handler-case
        (progn
          (log-info "Verifying server start/stop")

          ;; サーバー起動
          (setf server (start-test-server))
          (unless server
            (error "Failed to start server"))

          (log-info "Server started"
                    :context (list :|port| *test-server-port*))

          ;; 起動待機
          (sleep 1)

          ;; ヘルスチェック
          (unless (verify-health-check *test-server-port*)
            (error "Health check failed"))

          ;; サーバー停止
          (stop-test-server server)
          (setf server nil)

          (log-info "Server stopped"
                    :context (list :|port| *test-server-port*))

          ;; 成功
          (log-info "Server start/stop verification passed"
                    :context (list :|success| t))
          t)

      (error (e)
        (log-error "Server start/stop verification failed"
                   :error e
                   :context (list :|port| *test-server-port*))
        ;; クリーンアップ
        (when server
          (handler-case
              (stop-test-server server)
            (error (cleanup-error)
              (log-warn "Failed to cleanup server"
                        :context (list :|error| (princ-to-string cleanup-error))))))
        nil))))

(defun check-port-in-use (port)
  "ポートが使用中かどうかを確認

   引数:
     port: ポート番号

   戻り値: 使用中の場合T、空いている場合NIL"
  (handler-case
      (progn
        (dex:get (format nil "http://localhost:~D/" port)
                 :connect-timeout 1)
        ;; 接続できた = ポート使用中
        t)
    (dex:http-request-not-found ()
      ;; 404エラー = サーバーが起動している = ポート使用中
      t)
    (error ()
      ;; 接続エラー = ポートは空いている
      nil)))

(defun verify-port-conflict ()
  "ポート衝突時のエラーハンドリングを検証

   検証内容:
     1. サーバーを起動（ポート18080）
     2. ポートが使用中であることを確認
     3. サーバーを停止
     4. ポートが空いたことを確認

   戻り値: 成功時T、失敗時NIL"
  (let ((server nil))
    (handler-case
        (progn
          (log-info "Verifying port conflict handling")

          ;; サーバー起動前: ポートが空いていることを確認
          (when (check-port-in-use *test-server-port*)
            (error "Port ~D is already in use before test" *test-server-port*))

          (log-info "Port is available before server start"
                    :context (list :|port| *test-server-port*))

          ;; サーバー起動
          (setf server (start-test-server))
          (unless server
            (error "Failed to start server"))

          (log-info "Server started"
                    :context (list :|port| *test-server-port*))

          ;; 起動待機
          (sleep 1)

          ;; サーバー起動後: ポートが使用中であることを確認
          (unless (check-port-in-use *test-server-port*)
            (error "Port ~D is not in use after server start" *test-server-port*))

          (log-info "Port is in use after server start (expected)"
                    :context (list :|port| *test-server-port*))

          ;; サーバー停止
          (stop-test-server server)
          (setf server nil)

          ;; 停止後待機
          (sleep 0.5)

          ;; サーバー停止後: ポートが空いたことを確認
          (when (check-port-in-use *test-server-port*)
            (error "Port ~D is still in use after server stop" *test-server-port*))

          (log-info "Port is available after server stop (expected)"
                    :context (list :|port| *test-server-port*))

          ;; 成功
          (log-info "Port conflict verification passed"
                    :context (list :|success| t))
          t)

      (error (e)
        (log-error "Port conflict verification failed"
                   :error e
                   :context (list :|port| *test-server-port*))
        ;; クリーンアップ
        (when server
          (handler-case
              (stop-test-server server)
            (error (cleanup-error)
              (log-warn "Failed to cleanup server"
                        :context (list :|error| (princ-to-string cleanup-error))))))
        nil))))

;;;
;;; メイン実行関数
;;;

(defun run-all-tests ()
  "すべてのHTTPサーバー検証を実行

   戻り値: すべて成功時T、1つでも失敗時NIL"
  (let ((results '()))
    (handler-case
        (progn
          (format t "~%=================================================~%")
          (format t "  PoC: HTTP Server Verification Test~%")
          (format t "=================================================~%")
          (format t "~%--- Running Tests ---~%~%")

          ;; 検証実行
          (format t "Test 1/2: Server Start/Stop~%")
          (push (cons "Server Start/Stop" (verify-server-start-stop)) results)

          (format t "~%Test 2/2: Port Conflict~%")
          (push (cons "Port Conflict" (verify-port-conflict)) results)

          ;; 結果表示
          (format t "~%=================================================~%")
          (format t "  Test Results~%")
          (format t "=================================================~%~%")
          (dolist (result (reverse results))
            (format t "  ~A: ~A~%"
                    (car result)
                    (if (cdr result) "✓ PASSED" "✗ FAILED")))

          (let ((all-passed (every (lambda (r) (cdr r)) results)))
            (format t "~%Overall: ~A~%~%"
                    (if all-passed "✓ ALL TESTS PASSED" "✗ SOME TESTS FAILED"))

            (log-info "HTTP server verification completed"
                      :context (list :|results| (mapcar (lambda (r)
                                                          (list (car r) (cdr r)))
                                                        results)
                                     :|all_passed| all-passed))

            all-passed))

      (error (e)
        (log-error "HTTP server verification failed"
                   :error e
                   :context (list :|test_port| *test-server-port*))
        (format t "~%ERROR: ~A~%~%" e)
        nil))))

;; スクリプトとして実行された場合のエントリーポイント
(defun main ()
  "エントリーポイント"
  (let ((success (run-all-tests)))
    (if success
        (progn
          (format t "Exiting with status 0 (success)~%")
          (uiop:quit 0))
        (progn
          (format t "Exiting with status 1 (failure)~%")
          (uiop:quit 1)))))
