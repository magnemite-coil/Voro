(defpackage voro.test.middleware.session
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment
                :with-test-db)
  (:import-from :voro.test.fixtures
                :create-test-user
                :create-test-session)
  (:import-from :voro.middleware.session
                :generate-session-id
                :create-session
                :get-session-user-id
                :get-current-user-id
                :delete-session
                :session-exists-p)
  (:import-from :voro.model.user
                :user-id))

(in-package :voro.test.middleware.session)

;;;
;;; ヘルパー関数
;;;

(defun make-mock-request (&key cookies)
  "テスト用のモックrequestオブジェクトを作成
   cookies: alist形式 例: '((\"session_id\" . \"xxx\"))

   Note: lack.request:request構造体を動的に作成。
   パッケージシンボルは実行時に解決する。"
  (let ((make-fn (find-symbol "%MAKE-REQUEST" (find-package "LACK.REQUEST"))))
    (when make-fn
      (funcall make-fn :cookies cookies))))

;;;
;;; generate-session-id テスト
;;;

(deftest test-generate-session-id
  (testing "セッションIDの形式検証（32文字の16進数）"
    (let ((session-id (generate-session-id)))
      (ok (stringp session-id)
          "session-id is a string")
      (ok (= 32 (length session-id))
          "session-id is 32 characters")
      (ok (cl-ppcre:scan "^[0-9a-f]+$" session-id)
          "session-id contains only hex characters")))

  (testing "セッションIDの一意性検証"
    (let ((id1 (generate-session-id))
          (id2 (generate-session-id)))
      (ok (string/= id1 id2)
          "Two generated session IDs are different"))))

;;;
;;; create-session テスト
;;;

(deftest test-create-session
  (with-test-environment
    (with-test-db
      (testing "セッション作成と取得"
        (let* ((user (create-test-user))
               (user-id-val (user-id user))
               (session-id (create-session user-id-val)))
          (ok (stringp session-id)
              "create-session returns a string")
          (ok (= 32 (length session-id))
              "session-id is 32 characters")
          ;; Redisから取得できることを確認
          (ok (= user-id-val (get-session-user-id session-id))
              "session stores correct user_id"))))))

;;;
;;; get-session-user-id テスト
;;;

(deftest test-get-session-user-id
  (with-test-environment
    (with-test-db
      (testing "有効なセッションIDでuser_id取得"
        (let* ((user (create-test-user))
               (user-id-val (user-id user))
               (session-id (create-session user-id-val)))
          (ok (= user-id-val (get-session-user-id session-id))
              "Returns correct user_id for valid session")))

      (testing "無効なセッションIDでNIL"
        (ok (null (get-session-user-id "nonexistent-session-id-12345678"))
            "Returns NIL for nonexistent session"))

      (testing "NIL入力でNIL"
        (ok (null (get-session-user-id nil))
            "Returns NIL for NIL input")))))

;;;
;;; get-current-user-id テスト
;;;

(deftest test-get-current-user-id
  (with-test-environment
    (with-test-db
      (testing "有効なセッションCookieでuser_id取得"
        (let* ((user (create-test-user))
               (user-id-val (user-id user))
               (session-id (create-session user-id-val))
               (request (make-mock-request
                         :cookies (list (cons "session_id" session-id)))))
          (ok (= user-id-val (get-current-user-id request))
              "Returns correct user_id from valid session cookie")))

      (testing "無効なセッションCookieでNIL"
        (let ((request (make-mock-request
                        :cookies (list (cons "session_id" "invalid-session-id")))))
          (ok (null (get-current-user-id request))
              "Returns NIL for invalid session cookie")))

      (testing "Cookie無しでNIL"
        (let ((request (make-mock-request :cookies nil)))
          (ok (null (get-current-user-id request))
              "Returns NIL when no cookies")))

      (testing "session_id以外のCookieのみでNIL"
        (let ((request (make-mock-request
                        :cookies (list (cons "other_cookie" "value")))))
          (ok (null (get-current-user-id request))
              "Returns NIL when session_id cookie is missing"))))))

;;;
;;; delete-session テスト
;;;

(deftest test-delete-session
  (with-test-environment
    (with-test-db
      (testing "セッション削除"
        (let* ((user (create-test-user))
               (user-id-val (user-id user))
               (session-id (create-session user-id-val)))
          ;; 削除前は存在する
          (ok (session-exists-p session-id)
              "Session exists before deletion")
          ;; 削除
          (ok (delete-session session-id)
              "delete-session returns T")
          ;; 削除後は存在しない
          (ok (not (session-exists-p session-id))
              "Session does not exist after deletion")))

      (testing "存在しないセッションの削除（エラーなし）"
        ;; エラーが発生しないことを確認
        (ok (delete-session "nonexistent-session-id-12345678")
            "delete-session does not error for nonexistent session")))))

;;;
;;; session-exists-p テスト
;;;

(deftest test-session-exists-p
  (with-test-environment
    (with-test-db
      (testing "存在するセッション"
        (let* ((user (create-test-user))
               (user-id-val (user-id user))
               (session-id (create-session user-id-val)))
          (ok (session-exists-p session-id)
              "Returns T for existing session")))

      (testing "存在しないセッション"
        (ok (not (session-exists-p "nonexistent-session-id-12345678"))
            "Returns NIL for nonexistent session")))))

;;;
;;; テスト用補助関数
;;;

(defun make-session-redis-key (session-id)
  "テスト用: セッションIDからRedisキー名を生成
   注: 実装の session-key と同じフォーマットを維持すること"
  (format nil "session:~A" session-id))

;;;
;;; create-session エラーハンドリングテスト
;;;

(deftest test-create-session-redis-error
  (with-test-environment
    (with-test-db
      (testing "Redis障害時のエラーハンドリング"
        (let* ((user (create-test-user))
               (user-id-val (user-id user))
               (original-fn (symbol-function 'voro.redis:red-hset)))
          (unwind-protect
              (progn
                ;; red-hsetをスタブ化してエラーを発生させる
                ;; 注: 実装では red-hset → red-hset → red-expire の順で呼ばれるが、
                ;;     最初の red-hset でエラーが発生するため red-expire のスタブは不要
                (setf (symbol-function 'voro.redis:red-hset)
                      (lambda (&rest args)
                        (declare (ignore args))
                        (error "Simulated Redis error")))
                ;; 期待: エラーがシグナルされる
                (handler-case
                    (progn
                      (create-session user-id-val)
                      (fail "Should have signaled an error"))
                  (error (e)
                    ;; search は位置（整数）または NIL を返す
                    (ok (not (null (search "Session creation failed" (princ-to-string e))))
                        "Error message should contain 'Session creation failed'"))))
            ;; 必ず復元
            (setf (symbol-function 'voro.redis:red-hset) original-fn)))))))

;;;
;;; create-session created_at 検証テスト
;;;

(deftest test-create-session-created-at
  (with-test-environment
    (with-test-db
      (testing "セッションにcreated_atが保存される"
        (let* ((user (create-test-user))
               (user-id-val (user-id user))
               (time-before (get-universal-time))
               (session-id (create-session user-id-val))
               (time-after (get-universal-time))
               (redis-key (make-session-redis-key session-id)))
          (unwind-protect
              (let ((created-at-str (voro.redis:red-hget redis-key "created_at")))
                (ok (not (null created-at-str))
                    "created_at should be stored")
                (let ((created-at (parse-integer created-at-str)))
                  (ok (and (>= created-at time-before)
                           (<= created-at time-after))
                      "created_at should be within test execution time")))
            ;; 必ずセッションキーを削除（他テスト・Redisリソースへの影響を防止）
            (voro.redis:red-del redis-key)))))))

;;;
;;; get-session-user-id エラーハンドリングテスト
;;;

(deftest test-get-session-user-id-error-handling
  (with-test-environment
    ;; パターン1: Redis障害（スタブ化）
    (testing "Redis障害時はNILを返す"
      (let ((original-fn (symbol-function 'voro.redis:red-hget)))
        (unwind-protect
            (progn
              ;; red-hgetをスタブ化してエラーを発生させる
              (setf (symbol-function 'voro.redis:red-hget)
                    (lambda (&rest args)
                      (declare (ignore args))
                      (error "Simulated Redis error")))
              ;; 期待: NILを返す（エラーは伝播しない）
              (ok (null (get-session-user-id "any-session-id"))
                  "Should return NIL on Redis error"))
          ;; 必ず復元
          (setf (symbol-function 'voro.redis:red-hget) original-fn))))

    ;; パターン2: parse-integer失敗（実Redis使用）
    (testing "不正なuser_id文字列（parse-integer失敗）"
      (let* ((session-id (generate-session-id))
             (redis-key (make-session-redis-key session-id)))
        (unwind-protect
            (progn
              ;; 不正な値を直接セット
              (voro.redis:red-hset redis-key "user_id" "not-a-number")
              ;; 期待: NILを返す
              (ok (null (get-session-user-id session-id))
                  "Should return NIL for invalid user_id string"))
          ;; 必ずキーを削除（他テストへの影響を防止）
          (voro.redis:red-del redis-key))))))

;;;
;;; delete-session エラーハンドリングテスト
;;;

(deftest test-delete-session-error-handling
  (with-test-environment
    (testing "Redis障害時はNILを返す"
      (let ((original-fn (symbol-function 'voro.redis:red-del)))
        (unwind-protect
            (progn
              ;; red-delをスタブ化してエラーを発生させる
              (setf (symbol-function 'voro.redis:red-del)
                    (lambda (&rest args)
                      (declare (ignore args))
                      (error "Simulated Redis error")))
              ;; 期待: NILを返す（エラーは伝播しない）
              (ok (null (delete-session "any-session-id"))
                  "Should return NIL on Redis error"))
          ;; 必ず復元
          (setf (symbol-function 'voro.redis:red-del) original-fn))))))

;;;
;;; セッションTTL検証テスト
;;;

(deftest test-session-ttl
  (with-test-environment
    (with-test-db
      (testing "セッションにTTLが設定される"
        (let* ((user (create-test-user))
               (user-id-val (user-id user))
               (session-id (create-session user-id-val))
               (redis-key (make-session-redis-key session-id)))
          (unwind-protect
              (let ((ttl (voro.redis:red-ttl redis-key)))
                ;; TTLが設定されていることを確認（0より大きい）
                (ok (> ttl 0)
                    "TTL should be set (> 0)")
                ;; TTLが*session-ttl*以下であることを確認
                (ok (<= ttl voro.config:*session-ttl*)
                    (format nil "TTL (~A) should be <= *session-ttl* (~A)"
                            ttl voro.config:*session-ttl*))
                ;; TTLが*session-ttl*から2秒以内であることを確認
                ;; 注: 短TTL環境（例: SESSION_TTL=3）でも安定するよう固定マージン方式を採用
                ;;     - パーセンテージ方式（70%等）は短TTLで整数切り捨ての影響を受けるため不採用
                ;;     - マージン2秒: create-session→red-ttl間のスケジューリング遅延を考慮
                (ok (>= ttl (max 1 (- voro.config:*session-ttl* 2)))
                    (format nil "TTL (~A) should be >= *session-ttl* - 2 (~A)"
                            ttl (max 1 (- voro.config:*session-ttl* 2)))))
            ;; 必ずセッションキーを削除（他テスト・Redisリソースへの影響を防止）
            (voro.redis:red-del redis-key)))))))
