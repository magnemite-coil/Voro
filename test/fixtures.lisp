(defpackage voro.test.fixtures
  (:use :cl)
  (:import-from :voro.model.user
                :create-user
                :user-id
                :user-username)
  (:import-from :voro.middleware.session
                :create-session)
  (:export
   ;; ユーザーフィクスチャ
   :create-test-user
   :create-test-users

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
