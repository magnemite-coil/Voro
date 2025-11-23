;;;
;;; PoC: トランザクション検証スクリプト
;;;
;;; 目的: dbi:with-transaction が mito.connection:*connection* と互換性があり、
;;;       強制ロールバックが動作するかを検証
;;;

;; システムをロード
(ql:quickload :voro :silent t)

(defpackage voro.poc.transaction
  (:use :cl)
  (:import-from :voro.config
                :*app-env*
                :*db-name*)
  (:import-from :voro.db
                :connect-db
                :disconnect-db
                :*db-connection*)
  (:import-from :voro.util.log
                :log-info
                :log-warn
                :log-error)
  (:import-from :mito
                :execute-sql
                :ensure-table-exists
                :create-dao
                :find-dao)
  (:export :run-all-tests
           :main))

(in-package :voro.poc.transaction)

;;;
;;; テストロールバック用条件
;;;

(define-condition test-rollback-condition (error)
  ()
  (:documentation "テスト終了時の強制ロールバック用条件（エラーではない）"))

;;;
;;; ユーティリティ関数
;;;

(defun generate-test-username ()
  "テスト用ユーザー名を生成（タイムスタンプベース）"
  (format nil "poc-test-~A" (get-universal-time)))

(defun cleanup-test-data ()
  "テストデータをクリーンアップ

   戻り値: 成功時T、失敗時NIL

   実装方針:
     - PoC段階では execute-sql + 生SQL で実装（簡潔性を優先）
     - 実装完了後、SXQL版への置き換えを検討（判断基準は後述）"
  (handler-case
      (progn
        (mito:execute-sql
          "DELETE FROM \"user\" WHERE username LIKE 'poc-test-%'")
        (log-info "Test data cleaned up")
        t)
    (error (e)
      (log-warn "Failed to cleanup test data"
                :context (list :|error| (princ-to-string e)))
      nil)))

;;;
;;; DB接続の確認
;;;

(defun check-mito-connection ()
  "mito.connection:*connection* が存在するか確認

   戻り値: 存在する場合はシンボル、存在しない場合はNIL"
  (handler-case
      (progn
        (format t "~%Checking if mito.connection:*connection* exists...~%")
        (let ((symbol (find-symbol "*CONNECTION*" :mito.connection)))
          (if symbol
              (progn
                (format t "  ✓ mito.connection:*connection* found~%")
                symbol)
              (progn
                (format t "  ✗ mito.connection:*connection* not found~%")
                nil))))
    (error (e)
      (log-warn "Error checking mito.connection:*connection*"
                :context (list :|error| (princ-to-string e)))
      nil)))

(defun get-transaction-connection ()
  "トランザクションに使用する接続を取得

   戻り値: (values connection approach-name)
           connection: 接続オブジェクト
           approach-name: \"A\" (Mito) または \"B\" (DBI)"
  (let ((mito-conn-symbol (check-mito-connection)))
    (cond
      ;; アプローチA: mito.connection:*connection* を使用
      ((and mito-conn-symbol (boundp mito-conn-symbol))
       (let ((conn (symbol-value mito-conn-symbol)))
         (if conn
             (progn
               (format t "~%Using Approach A: mito.connection:*connection*~%")
               (values conn "A"))
             (progn
               (format t "~%mito.connection:*connection* is NIL, falling back to Approach B~%")
               (values voro.db:*db-connection* "B")))))

      ;; アプローチB: voro.db:*db-connection* を使用
      (t
       (format t "~%Using Approach B: voro.db:*db-connection*~%")
       (values voro.db:*db-connection* "B")))))

;;;
;;; 検証関数
;;;

(defun verify-transaction-rollback ()
  "トランザクション強制ロールバックを検証

   検証内容:
     1. トランザクション内でユーザー作成
     2. test-rollback-conditionで強制ロールバック
     3. ユーザーが保存されていないことを確認

   戻り値: 成功時T、失敗時NIL
   注: unwind-protectでテストデータを確実にクリーンアップ"
  (let ((test-username (generate-test-username))
        (conn (get-transaction-connection)))
    (unwind-protect
         (handler-case
             (progn
               (log-info "Verifying transaction rollback"
                         :context (list :|username| test-username))

               ;; トランザクション内でユーザー作成 + 強制ロールバック
               (handler-case
                   (dbi:with-transaction conn
                     ;; ユーザー作成
                     (mito:create-dao 'voro.model.user:user
                                      :username test-username
                                      :password "test-password-hash"
                                      :email "poc-test@example.com")

                     (log-info "Test user created in transaction"
                               :context (list :|username| test-username))

                     ;; 強制ロールバック
                     (error 'test-rollback-condition))
                 (test-rollback-condition ()
                   (log-info "Transaction rollback triggered")))

               ;; 検証: ユーザーが存在しないこと
               (let ((user (voro.model.user:find-user-by-username test-username)))
                 (if (null user)
                     (progn
                       (log-info "Transaction rollback verified"
                                 :context (list :|success| t))
                       t)
                     (progn
                       (log-error "Transaction rollback failed - user still exists"
                                  :context (list :|username| test-username))
                       nil))))

           (error (e)
             (log-error "Transaction rollback verification failed"
                        :error e
                        :context (list :|username| test-username))
             nil))

      ;; 終了処理（必ず実行）
      (cleanup-test-data))))

(defun verify-transaction-commit ()
  "トランザクション正常コミットを検証

   検証内容:
     1. トランザクション内でユーザー作成
     2. 正常終了（コミット）
     3. ユーザーが保存されていることを確認

   戻り値: 成功時T、失敗時NIL
   注: unwind-protectでテストデータを確実にクリーンアップ"
  (let ((test-username (generate-test-username))
        (conn (get-transaction-connection)))
    (unwind-protect
         (handler-case
             (progn
               (log-info "Verifying transaction commit"
                         :context (list :|username| test-username))

               ;; トランザクション内でユーザー作成（正常終了）
               (dbi:with-transaction conn
                 (mito:create-dao 'voro.model.user:user
                                  :username test-username
                                  :password "test-password-hash"
                                  :email "poc-test@example.com")

                 (log-info "Test user created in transaction"
                           :context (list :|username| test-username)))

               ;; 検証: ユーザーが存在すること
               (let ((user (voro.model.user:find-user-by-username test-username)))
                 (if user
                     (progn
                       (log-info "Transaction commit verified"
                                 :context (list :|success| t
                                                :|user_id| (voro.model.user:user-id user)))
                       t)
                     (progn
                       (log-error "Transaction commit failed - user not found"
                                  :context (list :|username| test-username))
                       nil))))

           (error (e)
             (log-error "Transaction commit verification failed"
                        :error e
                        :context (list :|username| test-username))
             nil))

      ;; 終了処理（必ず実行）
      (cleanup-test-data))))

(defun verify-transaction-error-rollback ()
  "トランザクションエラー時のロールバックを検証

   検証内容:
     1. トランザクション内でユーザー作成
     2. エラー発生（意図的）
     3. ユーザーが保存されていないことを確認

   戻り値: 成功時T、失敗時NIL
   注: unwind-protectでテストデータを確実にクリーンアップ"
  (let ((test-username (generate-test-username))
        (conn (get-transaction-connection)))
    (unwind-protect
         (handler-case
             (progn
               (log-info "Verifying transaction error rollback"
                         :context (list :|username| test-username))

               ;; トランザクション内でユーザー作成 + エラー発生
               (handler-case
                   (dbi:with-transaction conn
                     ;; ユーザー作成
                     (mito:create-dao 'voro.model.user:user
                                      :username test-username
                                      :password "test-password-hash"
                                      :email "poc-test@example.com")

                     (log-info "Test user created in transaction"
                               :context (list :|username| test-username))

                     ;; 意図的にエラー発生
                     (error "Intentional error for rollback test"))
                 (error (e)
                   (log-info "Transaction error caught"
                             :context (list :|error| (princ-to-string e)))))

               ;; 検証: ユーザーが存在しないこと
               (let ((user (voro.model.user:find-user-by-username test-username)))
                 (if (null user)
                     (progn
                       (log-info "Transaction error rollback verified"
                                 :context (list :|success| t))
                       t)
                     (progn
                       (log-error "Transaction error rollback failed - user still exists"
                                  :context (list :|username| test-username))
                       nil))))

           (error (e)
             (log-error "Transaction error rollback verification failed"
                        :error e
                        :context (list :|username| test-username))
             nil))

      ;; 終了処理（必ず実行）
      (cleanup-test-data))))

;;;
;;; メイン実行関数
;;;

(defun run-all-tests ()
  "すべてのトランザクション検証を実行

   戻り値: すべて成功時T、1つでも失敗時NIL"
  (let ((results '())
        (approach nil))
    (unwind-protect
         (handler-case
             (progn
               ;; 環境変数チェック
               (unless (string= *app-env* "test")
                 (error "APP_ENV must be 'test' (current: ~A)" *app-env*))

               (format t "~%=================================================~%")
               (format t "  PoC: Transaction Verification Test~%")
               (format t "=================================================~%")

               ;; DB接続
               (log-info "Connecting to database"
                         :context (list :|database| *db-name*))
               (connect-db)

               ;; テーブル作成
               (mito:ensure-table-exists 'voro.model.user:user)

               ;; 使用するアプローチを記録
               (multiple-value-bind (conn approach-name)
                   (get-transaction-connection)
                 (declare (ignore conn))
                 (setf approach approach-name))

               ;; 検証実行
               (format t "~%--- Running Tests ---~%~%")

               (format t "Test 1/3: Transaction Rollback~%")
               (push (cons "Transaction Rollback" (verify-transaction-rollback)) results)

               (format t "~%Test 2/3: Transaction Commit~%")
               (push (cons "Transaction Commit" (verify-transaction-commit)) results)

               (format t "~%Test 3/3: Transaction Error Rollback~%")
               (push (cons "Transaction Error Rollback" (verify-transaction-error-rollback)) results)

               ;; 結果表示
               (format t "~%=================================================~%")
               (format t "  Test Results~%")
               (format t "=================================================~%")
               (format t "Approach used: ~A~%" approach)
               (format t "~%")
               (dolist (result (reverse results))
                 (format t "  ~A: ~A~%"
                         (car result)
                         (if (cdr result) "✓ PASSED" "✗ FAILED")))

               (let ((all-passed (every (lambda (r) (cdr r)) results)))
                 (format t "~%Overall: ~A~%~%"
                         (if all-passed "✓ ALL TESTS PASSED" "✗ SOME TESTS FAILED"))

                 (log-info "Transaction verification completed"
                           :context (list :|results| (mapcar (lambda (r)
                                                               (list (car r) (cdr r)))
                                                             results)
                                          :|approach| approach
                                          :|all_passed| all-passed))

                 all-passed))

           (error (e)
             (log-error "Transaction verification failed"
                        :error e
                        :context (list :|database| *db-name*))
             (format t "~%ERROR: ~A~%~%" e)
             nil))

      ;; 終了処理（必ず実行）
      (disconnect-db))))

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
