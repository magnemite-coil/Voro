(defpackage voro.model.user
  (:use :cl :mito)
  (:import-from :voro.util.crypto
                :hash-password
                :verify-password)
  (:export
   :user
   :user-id
   :user-username
   ;; :user-password  ; 非公開 - verify-user-passwordのみを公開
   :user-email
   :user-created-at
   :user-updated-at
   :find-user-by-username
   :find-user-by-id
   :create-user
   :verify-user-password))

(in-package :voro.model.user)

;;; モデル定義

(mito:deftable user ()
  ((username :col-type (:varchar 50)
             :accessor user-username
             :initarg :username)
   (password :col-type (:varchar 255)
             :reader user-password    ; readerのみ（書き込み不可）
             :initarg :password)
   (email :col-type (or (:varchar 255) :null)
          :accessor user-email
          :initarg :email
          :initform nil))
  (:unique-keys username)
  (:table-name "user"))

;;; ヘルパー関数

(defun user-id (user)
  "ユーザーIDを取得（Mitoが自動生成するidカラム）"
  (mito:object-id user))

(defun user-created-at (user)
  "作成日時を取得（Mitoが自動生成）"
  (mito:object-created-at user))

(defun user-updated-at (user)
  "更新日時を取得（Mitoが自動生成）"
  (mito:object-updated-at user))

;;; クエリ関数

(defun find-user-by-username (username)
  "ユーザー名でユーザーを検索"
  (mito:find-dao 'user :username username))

(defun find-user-by-id (id)
  "IDでユーザーを検索"
  (mito:find-dao 'user :id id))

(defun create-user (username password &key email)
  "新規ユーザーを作成
   password: 平文パスワード（この関数内でハッシュ化される）"
  (let ((hashed-password (hash-password password)))
    (mito:create-dao 'user
                     :username username
                     :password hashed-password
                     :email email)))

(defun verify-user-password (user plain-password)
  "ユーザーのパスワードを検証"
  (verify-password plain-password (user-password user)))
