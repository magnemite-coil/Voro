(defpackage voro.test.model
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment)
  (:import-from :voro.model.user
                :create-user
                :find-user-by-username
                :verify-user-password)
  (:import-from :voro.model.post
                :post
                :post-id
                :post-user-id
                :post-title
                :post-content
                :post-published
                :find-post-by-id
                :find-posts-by-user-id
                :find-published-posts
                :count-published-posts
                :count-user-posts
                :create-post
                :post-to-alist))

(in-package :voro.test.model)

(deftest test-user-model
  (with-test-environment
    (testing "ユーザー作成とクエリ"
      (let ((user (create-user "modeltest" "password123" :email "model@example.com")))
        (ok (not (null user)))
        (ok (string= (voro.model.user:user-username user) "modeltest"))
        (ok (string= (voro.model.user:user-email user) "model@example.com"))))

    (testing "ユーザー名で検索"
      (create-user "findtest" "password123")
      (let ((found (find-user-by-username "findtest")))
        (ok (not (null found)))
        (ok (string= (voro.model.user:user-username found) "findtest"))))

    (testing "パスワード検証"
      (let ((user (create-user "passtest" "password123")))
        (ok (verify-user-password user "password123"))
        (ok (not (verify-user-password user "wrongpassword")))))))

(deftest test-post-model
  (with-test-environment
    (testing "投稿作成の基本動作"
      (let* ((user (create-user "postuser1" "password123"))
             (user-id (voro.model.user:user-id user))
             (post (create-post user-id "Test Title" "Test Content")))
        (ok (not (null post)))
        (ok (= (post-user-id post) user-id))
        (ok (string= (post-title post) "Test Title"))
        (ok (string= (post-content post) "Test Content"))
        (ok (null (post-published post)))))

    (testing "公開投稿の作成"
      (let* ((user (create-user "postuser2" "password123"))
             (user-id (voro.model.user:user-id user))
             (post (create-post user-id "Published Post" "Content" :published t)))
        (ok (eq (post-published post) t))))

    (testing "IDで投稿を検索"
      (let* ((user (create-user "postuser3" "password123"))
             (user-id (voro.model.user:user-id user))
             (post (create-post user-id "Find Test" "Content"))
             (found (find-post-by-id (post-id post))))
        (ok (not (null found)))
        (ok (string= (post-title found) "Find Test"))))

    (testing "存在しないIDの検索"
      (let ((found (find-post-by-id 999999)))
        (ok (null found))))

    (testing "公開投稿の検索"
      (let* ((user (create-user "postuser4" "password123"))
             (user-id (voro.model.user:user-id user)))
        ;; 公開投稿と非公開投稿を作成
        (create-post user-id "Published 1" "Content" :published t)
        (create-post user-id "Draft 1" "Content" :published nil)
        (create-post user-id "Published 2" "Content" :published t)
        (let ((posts (find-published-posts :limit 10)))
          ;; 公開投稿のみ取得される
          (ok (>= (length posts) 2))
          (ok (every (lambda (p) (eq (post-published p) t)) posts)))))

    (testing "ユーザーIDで投稿を検索（全件）"
      (let* ((user (create-user "postuser5" "password123"))
             (user-id (voro.model.user:user-id user)))
        (create-post user-id "Post A" "Content" :published t)
        (create-post user-id "Post B" "Content" :published nil)
        (let ((posts (find-posts-by-user-id user-id :published :all)))
          (ok (= (length posts) 2)))))

    (testing "ユーザーIDで投稿を検索（公開のみ）"
      (let* ((user (create-user "postuser6" "password123"))
             (user-id (voro.model.user:user-id user)))
        (create-post user-id "Public" "Content" :published t)
        (create-post user-id "Private" "Content" :published nil)
        (let ((posts (find-posts-by-user-id user-id :published t)))
          (ok (= (length posts) 1))
          (ok (string= (post-title (first posts)) "Public")))))

    (testing "ユーザーIDで投稿を検索（非公開のみ）"
      (let* ((user (create-user "postuser7" "password123"))
             (user-id (voro.model.user:user-id user)))
        (create-post user-id "Public" "Content" :published t)
        (create-post user-id "Private" "Content" :published nil)
        (let ((posts (find-posts-by-user-id user-id :published nil)))
          (ok (= (length posts) 1))
          (ok (string= (post-title (first posts)) "Private")))))

    (testing "公開投稿数のカウント"
      (let* ((user (create-user "postuser8" "password123"))
             (user-id (voro.model.user:user-id user))
             (initial-count (count-published-posts)))
        (create-post user-id "Count Test" "Content" :published t)
        (ok (= (count-published-posts) (1+ initial-count)))))

    (testing "ユーザー投稿数のカウント"
      (let* ((user (create-user "postuser9" "password123"))
             (user-id (voro.model.user:user-id user)))
        (create-post user-id "Post 1" "Content" :published t)
        (create-post user-id "Post 2" "Content" :published nil)
        (ok (= (count-user-posts user-id :published :all) 2))
        (ok (= (count-user-posts user-id :published t) 1))
        (ok (= (count-user-posts user-id :published nil) 1))))

    (testing "post-to-alist変換"
      (let* ((user (create-user "postuser10" "password123"))
             (user-id (voro.model.user:user-id user))
             (post (create-post user-id "Alist Test" "Content" :published t))
             (alist (post-to-alist post)))
        (ok (assoc :|id| alist))
        (ok (assoc :|user_id| alist))
        (ok (assoc :|title| alist))
        (ok (assoc :|content| alist))
        (ok (assoc :|published| alist))
        (ok (assoc :|created_at| alist))
        (ok (assoc :|updated_at| alist))
        (ok (string= (cdr (assoc :|title| alist)) "Alist Test"))))))
