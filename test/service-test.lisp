(defpackage voro.test.service
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment)
  (:import-from :voro.service.auth
                :register-user
                :authenticate-user
                :logout-user)
  (:import-from :voro.middleware.session
                :session-exists-p)
  (:import-from :voro.service.post
                :create-new-post
                :get-post
                :update-post
                :delete-post
                :list-published-posts
                :list-user-posts
                :list-my-posts)
  (:import-from :voro.model.post
                :post-id
                :post-title
                :post-content
                :post-published)
  (:import-from :voro.util.validation
                :validation-error
                :authorization-error
                :not-found-error))

(in-package :voro.test.service)

(deftest test-register-user
  (with-test-environment
    (testing "新規ユーザー登録成功"
      (multiple-value-bind (user session-id)
          (register-user "testuser" "password123" :email "test@example.com")
        (ok (not (null user)))
        (ok (not (null session-id)))
        (ok (string= (voro.model.user:user-username user) "testuser"))))

    (testing "重複ユーザー名でエラー"
      (register-user "duplicate" "password123" :email "dup@example.com")
      (ok (signals (register-user "duplicate" "password123" :email "dup2@example.com")
                   'voro.util.validation:validation-error)))

    (testing "パスワードが短すぎる場合エラー"
      (ok (signals (register-user "newuser" "pass1" :email "new@example.com")
                   'voro.util.validation:validation-error)))

    (testing "パスワードに数字が含まれない場合エラー"
      (ok (signals (register-user "newuser" "password" :email "new@example.com")
                   'voro.util.validation:validation-error)))

    (testing "パスワードに英字が含まれない場合エラー"
      (ok (signals (register-user "newuser" "12345678" :email "new@example.com")
                   'voro.util.validation:validation-error)))

    (testing "ユーザー名が短すぎる場合エラー"
      (ok (signals (register-user "ab" "password123" :email "new@example.com")
                   'voro.util.validation:validation-error)))

    (testing "ユーザー名が長すぎる場合エラー"
      (ok (signals (register-user (make-string 51 :initial-element #\a) "password123" :email "new@example.com")
                   'voro.util.validation:validation-error)))

    (testing "ユーザー名に不正な文字が含まれる場合エラー"
      (ok (signals (register-user "user@name" "password123" :email "new@example.com")
                   'voro.util.validation:validation-error)))))

(deftest test-authenticate-user
  (with-test-environment
    ;; テストユーザー作成
    (register-user "logintest" "password123" :email "login@example.com")

    (testing "正しい認証情報でログイン成功"
      (multiple-value-bind (user session-id)
          (authenticate-user "logintest" "password123")
        (ok (not (null user)))
        (ok (not (null session-id)))))

    (testing "間違ったパスワードで失敗"
      (let ((result (authenticate-user "logintest" "wrongpassword")))
        (ok (null result))))))

;;;
;;; logout-user テスト（test/service-test.lisp に追加）
;;;

(deftest test-logout-user
  (with-test-environment
    (testing "正常なログアウト"
      (multiple-value-bind (user session-id)
          (register-user "logouttest" "password123" :email "logout@example.com")
        (declare (ignore user))
        ;; セッションが存在することを確認
        (ok (session-exists-p session-id)
            "Session should exist before logout")
        ;; ログアウト
        (logout-user session-id)
        ;; セッションが削除されたことを確認
        (ok (not (session-exists-p session-id))
            "Session should not exist after logout")))

    (testing "存在しないセッションIDでのログアウト（冪等性）"
      ;; 存在しないセッションIDでもエラーが発生しないことを確認
      ;; 事前にセッションが存在しないことを確認し、冪等性を強化
      ;; 注: セッションIDは32文字の16進数形式（src/middleware/session.lisp:23-26）
      (let ((fake-session-id "00000000000000000000000000000000"))
        ;; 事前確認: セッションが存在しないこと
        (ok (not (session-exists-p fake-session-id))
            "Session should not exist before logout attempt")
        ;; ログアウト実行（エラーが発生しないこと）
        (handler-case
            (progn
              (logout-user fake-session-id)
              (ok t "Logout with nonexistent session should not raise error"))
          (error (e)
            (declare (ignore e))
            (ok nil "Logout raised an unexpected error")))
        ;; 事後確認: セッションが依然として存在しないこと
        (ok (not (session-exists-p fake-session-id))
            "Session should still not exist after logout attempt")))))

(deftest test-authenticate-user-edge-cases
  (with-test-environment
    (testing "存在しないユーザーでログイン失敗"
      (let ((result (authenticate-user "nonexistentuser" "password123")))
        (ok (null result)
            "Authentication with nonexistent user returns NIL")))))

;;; Post Service テスト

(deftest test-create-new-post
  (with-test-environment
    (testing "正常な投稿作成"
      (multiple-value-bind (user session-id)
          (register-user "postcreator1" "password123" :email "pc1@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (post (create-new-post user-id "Test Title" "Test Content")))
          (ok (not (null post)))
          (ok (string= (post-title post) "Test Title"))
          (ok (string= (post-content post) "Test Content"))
          (ok (null (post-published post))))))

    (testing "公開投稿の作成"
      (multiple-value-bind (user session-id)
          (register-user "postcreator2" "password123" :email "pc2@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (post (create-new-post user-id "Published" "Content" :published t)))
          (ok (eq (post-published post) t)))))

    (testing "タイトルなしでエラー"
      (multiple-value-bind (user session-id)
          (register-user "postcreator3" "password123" :email "pc3@example.com")
        (declare (ignore session-id))
        (let ((user-id (voro.model.user:user-id user)))
          (ok (signals (create-new-post user-id nil "Content")
                       'validation-error)))))

    (testing "空白のみのタイトルでエラー"
      (multiple-value-bind (user session-id)
          (register-user "postcreator4" "password123" :email "pc4@example.com")
        (declare (ignore session-id))
        (let ((user-id (voro.model.user:user-id user)))
          (ok (signals (create-new-post user-id "   " "Content")
                       'validation-error)))))

    (testing "本文なしでエラー"
      (multiple-value-bind (user session-id)
          (register-user "postcreator5" "password123" :email "pc5@example.com")
        (declare (ignore session-id))
        (let ((user-id (voro.model.user:user-id user)))
          (ok (signals (create-new-post user-id "Title" nil)
                       'validation-error)))))))

(deftest test-get-post
  (with-test-environment
    (testing "公開投稿の取得（認証なし）"
      (multiple-value-bind (user session-id)
          (register-user "getpost1" "password123" :email "gp1@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (post (create-new-post user-id "Public Post" "Content" :published t))
               (found (get-post (post-id post))))
          (ok (not (null found)))
          (ok (string= (post-title found) "Public Post")))))

    (testing "非公開投稿の取得（所有者）"
      (multiple-value-bind (user session-id)
          (register-user "getpost2" "password123" :email "gp2@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (post (create-new-post user-id "Draft" "Content" :published nil))
               (found (get-post (post-id post) :session-user-id user-id)))
          (ok (not (null found))))))

    (testing "非公開投稿の取得（非所有者）"
      (multiple-value-bind (user1 session-id1)
          (register-user "getpost3" "password123" :email "gp3@example.com")
        (declare (ignore session-id1))
        (multiple-value-bind (user2 session-id2)
            (register-user "getpost4" "password123" :email "gp4@example.com")
          (declare (ignore session-id2))
          (let* ((owner-id (voro.model.user:user-id user1))
                 (other-id (voro.model.user:user-id user2))
                 (post (create-new-post owner-id "Draft" "Content" :published nil))
                 (found (get-post (post-id post) :session-user-id other-id)))
            (ok (null found))))))

    (testing "存在しない投稿の取得"
      (let ((found (get-post 999999)))
        (ok (null found))))))

(deftest test-update-post
  (with-test-environment
    (testing "正常な更新"
      (multiple-value-bind (user session-id)
          (register-user "updatepost1" "password123" :email "up1@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (post (create-new-post user-id "Original" "Content"))
               (updated (update-post (post-id post) user-id :title "Updated")))
          (ok (string= (post-title updated) "Updated")))))

    (testing "公開状態の変更"
      (multiple-value-bind (user session-id)
          (register-user "updatepost2" "password123" :email "up2@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (post (create-new-post user-id "Draft" "Content" :published nil))
               (updated (update-post (post-id post) user-id :published t)))
          (ok (eq (post-published updated) t)))))

    (testing "他人の投稿を更新しようとしてエラー"
      (multiple-value-bind (user1 session-id1)
          (register-user "updatepost3" "password123" :email "up3@example.com")
        (declare (ignore session-id1))
        (multiple-value-bind (user2 session-id2)
            (register-user "updatepost4" "password123" :email "up4@example.com")
          (declare (ignore session-id2))
          (let* ((owner-id (voro.model.user:user-id user1))
                 (other-id (voro.model.user:user-id user2))
                 (post (create-new-post owner-id "Original" "Content")))
            (ok (signals (update-post (post-id post) other-id :title "Hack")
                         'authorization-error))))))

    (testing "存在しない投稿を更新しようとしてエラー"
      (multiple-value-bind (user session-id)
          (register-user "updatepost5" "password123" :email "up5@example.com")
        (declare (ignore session-id))
        (let ((user-id (voro.model.user:user-id user)))
          (ok (signals (update-post 999999 user-id :title "Test")
                       'not-found-error)))))))

(deftest test-delete-post
  (with-test-environment
    (testing "正常な削除"
      (multiple-value-bind (user session-id)
          (register-user "deletepost1" "password123" :email "dp1@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (post (create-new-post user-id "ToDelete" "Content"))
               (post-id-val (post-id post)))
          (ok (delete-post post-id-val user-id))
          ;; 削除後は取得できない
          (ok (null (get-post post-id-val))))))

    (testing "他人の投稿を削除しようとしてエラー"
      (multiple-value-bind (user1 session-id1)
          (register-user "deletepost2" "password123" :email "dp2@example.com")
        (declare (ignore session-id1))
        (multiple-value-bind (user2 session-id2)
            (register-user "deletepost3" "password123" :email "dp3@example.com")
          (declare (ignore session-id2))
          (let* ((owner-id (voro.model.user:user-id user1))
                 (other-id (voro.model.user:user-id user2))
                 (post (create-new-post owner-id "Original" "Content")))
            (ok (signals (delete-post (post-id post) other-id)
                         'authorization-error))))))

    (testing "存在しない投稿を削除しようとしてエラー"
      (multiple-value-bind (user session-id)
          (register-user "deletepost4" "password123" :email "dp4@example.com")
        (declare (ignore session-id))
        (let ((user-id (voro.model.user:user-id user)))
          (ok (signals (delete-post 999999 user-id)
                       'not-found-error)))))))

(deftest test-list-posts
  (with-test-environment
    (testing "公開投稿一覧の取得"
      (multiple-value-bind (user session-id)
          (register-user "listpost1" "password123" :email "lp1@example.com")
        (declare (ignore session-id))
        (let ((user-id (voro.model.user:user-id user)))
          (create-new-post user-id "Public 1" "Content" :published t)
          (create-new-post user-id "Public 2" "Content" :published t)
          (create-new-post user-id "Draft" "Content" :published nil)
          (multiple-value-bind (posts pagination)
              (list-published-posts :page 1 :per-page 10)
            (ok (>= (length posts) 2))
            (ok (assoc :|page| pagination))
            (ok (assoc :|per_page| pagination))
            (ok (assoc :|total_count| pagination))
            (ok (assoc :|total_pages| pagination))))))

    (testing "特定ユーザーの公開投稿一覧"
      (multiple-value-bind (user session-id)
          (register-user "listpost2" "password123" :email "lp2@example.com")
        (declare (ignore session-id))
        (let ((user-id (voro.model.user:user-id user)))
          (create-new-post user-id "User Public" "Content" :published t)
          (create-new-post user-id "User Draft" "Content" :published nil)
          (multiple-value-bind (posts pagination)
              (list-user-posts user-id :page 1 :per-page 10)
            (declare (ignore pagination))
            (ok (= (length posts) 1))
            (ok (string= (post-title (first posts)) "User Public"))))))

    (testing "自分の投稿一覧（全件）"
      (multiple-value-bind (user session-id)
          (register-user "listpost3" "password123" :email "lp3@example.com")
        (declare (ignore session-id))
        (let ((user-id (voro.model.user:user-id user)))
          (create-new-post user-id "My Public" "Content" :published t)
          (create-new-post user-id "My Draft" "Content" :published nil)
          (multiple-value-bind (posts pagination)
              (list-my-posts user-id :page 1 :per-page 10 :published :all)
            (declare (ignore pagination))
            (ok (= (length posts) 2))))))

    (testing "自分の投稿一覧（公開のみ）"
      (multiple-value-bind (user session-id)
          (register-user "listpost4" "password123" :email "lp4@example.com")
        (declare (ignore session-id))
        (let ((user-id (voro.model.user:user-id user)))
          (create-new-post user-id "Only Public" "Content" :published t)
          (create-new-post user-id "Only Draft" "Content" :published nil)
          (multiple-value-bind (posts pagination)
              (list-my-posts user-id :page 1 :per-page 10 :published t)
            (declare (ignore pagination))
            (ok (= (length posts) 1))
            (ok (string= (post-title (first posts)) "Only Public"))))))

    (testing "自分の投稿一覧（非公開のみ）"
      (multiple-value-bind (user session-id)
          (register-user "listpost5" "password123" :email "lp5@example.com")
        (declare (ignore session-id))
        (let ((user-id (voro.model.user:user-id user)))
          (create-new-post user-id "Filter Public" "Content" :published t)
          (create-new-post user-id "Filter Draft" "Content" :published nil)
          (multiple-value-bind (posts pagination)
              (list-my-posts user-id :page 1 :per-page 10 :published nil)
            (declare (ignore pagination))
            (ok (= (length posts) 1))
            (ok (string= (post-title (first posts)) "Filter Draft"))))))))

;;;
;;; create-new-post 境界値テスト
;;;

(deftest test-create-new-post-edge-cases
  (with-test-environment
    (testing "タイトル境界値 - 空文字はNG"
      (multiple-value-bind (user session-id)
          (register-user "titletest0" "password123" :email "t0@example.com")
        (declare (ignore session-id))
        (let ((user-id (voro.model.user:user-id user)))
          (ok (signals (create-new-post user-id "" "Valid content")
                       'validation-error)
              "Empty title should fail"))))

    (testing "タイトル境界値 - 1文字はOK"
      (multiple-value-bind (user session-id)
          (register-user "titletest1" "password123" :email "t1@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (post (create-new-post user-id "A" "Valid content here")))
          (ok (not (null post))
              "Post should be created")
          (ok (string= (post-title post) "A")
              "Title should be 'A'"))))

    (testing "タイトル境界値 - 200文字はOK"
      (multiple-value-bind (user session-id)
          (register-user "titletest2" "password123" :email "t2@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (title-200 (make-string 200 :initial-element #\T))
               (post (create-new-post user-id title-200 "Valid content")))
          (ok (= (length (post-title post)) 200)
              "Title should be 200 characters"))))

    (testing "タイトル境界値 - 201文字はNG"
      (multiple-value-bind (user session-id)
          (register-user "titletest3" "password123" :email "t3@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (title-201 (make-string 201 :initial-element #\T)))
          (ok (signals (create-new-post user-id title-201 "Valid content")
                       'validation-error)
              "201 characters should fail"))))

    (testing "タイトル - 空白のみはNG"
      (multiple-value-bind (user session-id)
          (register-user "titletest4" "password123" :email "t4@example.com")
        (declare (ignore session-id))
        (let ((user-id (voro.model.user:user-id user)))
          (ok (signals (create-new-post user-id "   " "Valid content")
                       'validation-error)
              "Whitespace-only title should fail"))))

    (testing "コンテンツ境界値 - 空文字はNG"
      (multiple-value-bind (user session-id)
          (register-user "contenttest0" "password123" :email "c0@example.com")
        (declare (ignore session-id))
        (let ((user-id (voro.model.user:user-id user)))
          (ok (signals (create-new-post user-id "Valid Title" "")
                       'validation-error)
              "Empty content should fail"))))

    (testing "コンテンツ境界値 - 1文字はOK"
      (multiple-value-bind (user session-id)
          (register-user "contenttest1" "password123" :email "c1@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (post (create-new-post user-id "Valid Title" "C")))
          (ok (string= (post-content post) "C")
              "Content should be 'C'"))))

    (testing "コンテンツ - 長いテキスト（10000文字）はOK"
      (multiple-value-bind (user session-id)
          (register-user "contenttest2" "password123" :email "c2@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (long-content (make-string 10000 :initial-element #\X))
               (post (create-new-post user-id "Title" long-content)))
          (ok (= (length (post-content post)) 10000)
              "Content should be 10000 characters"))))

    (testing "コンテンツ境界値 - 100000文字はOK"
      (multiple-value-bind (user session-id)
          (register-user "contenttest3" "password123" :email "c3@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (max-content (make-string 100000 :initial-element #\X))
               (post (create-new-post user-id "Title" max-content)))
          (ok (= (length (post-content post)) 100000)
              "Content should be 100000 characters"))))

    (testing "コンテンツ境界値 - 100001文字はNG"
      (multiple-value-bind (user session-id)
          (register-user "contenttest4" "password123" :email "c4@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (over-content (make-string 100001 :initial-element #\X)))
          (ok (signals (create-new-post user-id "Title" over-content)
                       'validation-error)
              "100001 characters should fail"))))))

;;;
;;; セキュリティテスト
;;;

(deftest test-create-new-post-security
  (with-test-environment
    (testing "HTMLタグを含むタイトルはそのまま保存される"
      (multiple-value-bind (user session-id)
          (register-user "sectest1" "password123" :email "sec1@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (xss-title "<script>alert(1)</script>")
               (post (create-new-post user-id xss-title "Content")))
          (ok (string= (post-title post) xss-title)
              "XSS string should be stored as-is"))))

    (testing "SQLインジェクション風文字列は通常の文字列として保存される"
      (multiple-value-bind (user session-id)
          (register-user "sectest2" "password123" :email "sec2@example.com")
        (declare (ignore session-id))
        (let* ((user-id (voro.model.user:user-id user))
               (sql-title "'; DROP TABLE post; --")
               (post (create-new-post user-id sql-title "Content")))
          (ok (string= (post-title post) sql-title)
              "SQL injection string should be stored safely"))))))

;;;
;;; ページネーション正規化テスト
;;;

(deftest test-list-published-posts-pagination
  (with-test-environment
    (testing "ページネーション正規化 - page=0は1に正規化"
      (multiple-value-bind (posts pagination)
          (list-published-posts :page 0 :per-page 10)
        (declare (ignore posts))
        (ok (= (cdr (assoc :|page| pagination)) 1)
            "page=0 should be normalized to 1")))

    (testing "ページネーション正規化 - page=-1は1に正規化"
      (multiple-value-bind (posts pagination)
          (list-published-posts :page -1 :per-page 10)
        (declare (ignore posts))
        (ok (= (cdr (assoc :|page| pagination)) 1)
            "page=-1 should be normalized to 1")))

    (testing "ページネーション正規化 - per_page=0は1に正規化"
      (multiple-value-bind (posts pagination)
          (list-published-posts :page 1 :per-page 0)
        (declare (ignore posts))
        (ok (= (cdr (assoc :|per_page| pagination)) 1)
            "per_page=0 should be normalized to 1")))

    (testing "ページネーション正規化 - per_page=101は100に正規化"
      (multiple-value-bind (posts pagination)
          (list-published-posts :page 1 :per-page 101)
        (declare (ignore posts))
        (ok (= (cdr (assoc :|per_page| pagination)) 100)
            "per_page=101 should be capped at 100")))

    (testing "ページネーション正規化 - page=10001は10000に正規化"
      (multiple-value-bind (posts pagination)
          (list-published-posts :page 10001 :per-page 10)
        (declare (ignore posts))
        (ok (= (cdr (assoc :|page| pagination)) 10000)
            "page=10001 should be capped at 10000")))))
