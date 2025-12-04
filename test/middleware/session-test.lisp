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
