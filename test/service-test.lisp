(defpackage voro.test.service
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment)
  (:import-from :voro.service.auth
                :register-user
                :authenticate-user)
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
