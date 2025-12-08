(defpackage voro.test.fixtures
  (:use :cl)
  (:import-from :voro.model.user
                :create-user
                :user-id
                :user-username)
  (:import-from :voro.model.post
                :create-post)
  (:import-from :voro.middleware.session
                :create-session)
  (:export
   ;; ユーザーフィクスチャ
   :create-test-user
   :create-test-users

   ;; 投稿フィクスチャ
   :create-test-post
   :create-test-posts
   :*default-test-post-title*
   :*default-test-post-content*

   ;; セッションフィクスチャ
   :create-test-session

   ;; デフォルト値
   :*default-test-username*
   :*default-test-password*
   :*default-test-email*))

(in-package :voro.test.fixtures)

;;;
;;; デフォルト値
;;;

(defparameter *default-test-username* "testuser"
  "テストユーザーのデフォルトユーザー名")

(defparameter *default-test-password* "TestP@ssw0rd123"
  "テストユーザーのデフォルトパスワード")

(defparameter *default-test-email* "test@example.com"
  "テストユーザーのデフォルトメールアドレス")

;;;
;;; カウンター（ユニークなユーザー名生成用）
;;;

(defparameter *test-user-counter* 0
  "テストユーザー生成カウンター")

(defun next-test-username ()
  "ユニークなテストユーザー名を生成"
  (incf *test-user-counter*)
  (format nil "testuser~D" *test-user-counter*))

;;;
;;; ユーザーフィクスチャ
;;;

(defun create-test-user (&key
                           (username (next-test-username))
                           (password *default-test-password*)
                           (email *default-test-email*))
  "テスト用ユーザーを作成

  引数:
    username: ユーザー名（デフォルト: testuser1, testuser2, ...）
    password: パスワード（デフォルト: TestP@ssw0rd123）
    email: メールアドレス（デフォルト: test@example.com）

  戻り値: userオブジェクト

  使用例:
    ;; デフォルト値で作成
    (let ((user (create-test-user)))
      (ok (not (null user))))

    ;; カスタマイズ
    (let ((user (create-test-user :username \"customuser\"
                                  :password \"custom123\")))
      (ok (string= (user-username user) \"customuser\")))"

  (create-user username password :email email))

(defun create-test-users (count &key
                                  (password *default-test-password*)
                                  (email *default-test-email*))
  "複数のテスト用ユーザーを作成

  引数:
    count: 作成するユーザー数
    password: 共通パスワード
    email: 共通メールアドレス

  戻り値: userオブジェクトのリスト

  使用例:
    (let ((users (create-test-users 5)))
      (ok (= (length users) 5)))"

  (loop repeat count
        collect (create-test-user :password password :email email)))

;;;
;;; セッションフィクスチャ
;;;

(defun create-test-session (&optional user)
  "テスト用セッションを作成

  引数:
    user: userオブジェクト（省略時は新規ユーザーを作成）

  戻り値: (values session-id user)

  使用例:
    ;; 新規ユーザー + セッション
    (multiple-value-bind (session-id user)
        (create-test-session)
      (ok (stringp session-id))
      (ok (not (null user))))

    ;; 既存ユーザーでセッション作成
    (let* ((user (create-test-user))
           (session-id (create-test-session user)))
      (ok (stringp session-id)))"

  (let ((user (or user (create-test-user))))
    (values (create-session (user-id user)) user)))

;;;
;;; 投稿フィクスチャ
;;;

(defparameter *default-test-post-title* "Test Post Title"
  "テスト投稿のデフォルトタイトル")

(defparameter *default-test-post-content* "Test post content for testing purposes."
  "テスト投稿のデフォルト本文")

(defun create-test-post (&key
                           user
                           (title *default-test-post-title*)
                           (content *default-test-post-content*)
                           (published nil))
  "テスト用投稿を作成

  引数:
    user: userオブジェクト（省略時は新規ユーザーを作成）
    title: タイトル（デフォルト: Test Post Title）
    content: 本文（デフォルト: Test post content...）
    published: 公開フラグ（デフォルト: nil）

  戻り値: (values post user)
    - 第一戻り値: postオブジェクト
    - 第二戻り値: userオブジェクト（:userを省略した場合に有用）

  使用例:
    ;; 新規ユーザー + 投稿（両方の戻り値を使用）
    (multiple-value-bind (post user)
        (create-test-post)
      (ok (not (null post))))

    ;; 既存ユーザーで投稿作成（postのみ使用、第二戻り値は無視）
    (let* ((user (create-test-user))
           (post (create-test-post :user user :published t)))
      (ok (post-published post)))"

  (let ((user (or user (create-test-user))))
    (values (create-post
             (user-id user)
             title
             content
             :published published)
            user)))

(defun create-test-posts (count &key
                                  user
                                  (published nil))
  "複数のテスト用投稿を作成

  引数:
    count: 作成する投稿数
    user: 投稿者（省略時は新規ユーザーを作成）
    published: 共通公開フラグ

  戻り値: (values posts user)"

  (let ((user (or user (create-test-user))))
    (values
     (loop for i from 1 to count
           collect (create-post
                    (user-id user)
                    (format nil "Test Post ~D" i)
                    (format nil "Content for post ~D" i)
                    :published published))
     user)))
