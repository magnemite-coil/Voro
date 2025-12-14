(defpackage voro.model.post
  (:use :cl :mito)
  (:import-from :voro.model.user
                :user
                :user-id
                :find-user-by-id)
  (:import-from :local-time
                :format-timestring
                :+iso-8601-format+)
  (:export
   :post
   :post-id
   :post-user-id
   :post-user
   :post-title
   :post-content
   :post-published
   :post-created-at
   :post-updated-at
   :find-post-by-id
   :find-posts-by-user-id
   :find-published-posts
   :count-published-posts
   :count-user-posts
   :create-post
   :post-to-alist))

(in-package :voro.model.post)

;;; モデル定義
;;; 注意: スロット名はハイフン区切り（user-id）、:col-nameでDBカラム名（user_id）を指定
;;;
;;; FK制約について:
;;; - Mitoは :col-type に他のテーブルクラスを指定すると関係を認識する
;;; - ただし、DBレベルのFK制約は自動生成されない
;;; - DBレベルのFK制約はマイグレーションで追加する（scripts/add-fk-constraint.sql）

(mito:deftable post ()
  ((user :col-type user
         :col-name "user_id"
         :accessor post-user
         :initarg :user)
   (title :col-type (:varchar 200)
          :accessor post-title
          :initarg :title)
   (content :col-type :text
            :accessor post-content
            :initarg :content)
   (published :col-type :boolean
              :accessor post-published
              :initarg :published
              :initform nil))
  (:table-name "post")
  (:indexes (:user)))

;;; ヘルパー関数

(defun post-id (post)
  "投稿IDを取得"
  (mito:object-id post))

(defun post-user-id (post)
  "投稿の所有者ユーザーIDを取得
   注: Mitoは :col-type に他のクラスを指定した場合、
       内部的に *-id スロットを作成するが、明示的に定義して安全性を確保"
  (let ((user-obj (post-user post)))
    (when user-obj
      (user-id user-obj))))

(defun post-created-at (post)
  "作成日時を取得"
  (mito:object-created-at post))

(defun post-updated-at (post)
  "更新日時を取得"
  (mito:object-updated-at post))

;;; クエリ関数

(defun find-post-by-id (id)
  "IDで投稿を検索"
  (mito:find-dao 'post :id id))

(defun find-posts-by-user-id (user-id &key (published :all) (limit 20) (offset 0))
  "ユーザーIDで投稿を検索
   published: :all（全件）、t（公開のみ）、nil（非公開のみ）
   注意: SXQLでboolean値を扱う場合、:raw でSQLリテラルを直接挿入する
         (:raw \"published = TRUE\") → 'published = TRUE'"
  (cond
    ((eq published :all)
     (mito:select-dao 'post
       (sxql:where (:= :user_id user-id))
       (sxql:order-by (:desc :created_at))
       (sxql:limit limit)
       (sxql:offset offset)))
    (published
     (mito:select-dao 'post
       (sxql:where (:and (:= :user_id user-id)
                         (:raw "\"published\" = TRUE")))
       (sxql:order-by (:desc :created_at))
       (sxql:limit limit)
       (sxql:offset offset)))
    (t
     (mito:select-dao 'post
       (sxql:where (:and (:= :user_id user-id)
                         (:raw "\"published\" = FALSE")))
       (sxql:order-by (:desc :created_at))
       (sxql:limit limit)
       (sxql:offset offset)))))

(defun find-published-posts (&key (limit 20) (offset 0))
  "公開投稿を検索（新着順）"
  (mito:select-dao 'post
    (sxql:where (:raw "\"published\" = TRUE"))
    (sxql:order-by (:desc :created_at))
    (sxql:limit limit)
    (sxql:offset offset)))

(defun count-published-posts ()
  "公開投稿数をカウント
   注意: boolean条件でのカウントはselect-dao + lengthを使用"
  (length (mito:select-dao 'post
            (sxql:where (:raw "\"published\" = TRUE")))))

(defun count-user-posts (user-id &key (published :all))
  "ユーザーの投稿数をカウント
   published: :all（全件）、t（公開のみ）、nil（非公開のみ）
   注意: boolean条件でのカウントはselect-dao + lengthを使用"
  (cond
    ((eq published :all)
     (mito:count-dao 'post :user-id user-id))
    (published
     ;; 公開投稿のカウント
     (length (mito:select-dao 'post
               (sxql:where (:and (:= :user_id user-id)
                                 (:raw "\"published\" = TRUE"))))))
    (t
     ;; 非公開投稿のカウント
     (length (mito:select-dao 'post
               (sxql:where (:and (:= :user_id user-id)
                                 (:raw "\"published\" = FALSE"))))))))

(defun create-post (user-id title content &key (published nil))
  "新規投稿を作成
   user-id: ユーザーID（整数）またはuserオブジェクト

   注: Mitoの :col-type user 定義により、:user キーワードには
       userオブジェクトを渡す必要がある。整数IDが渡された場合は
       DBからuserオブジェクトを取得してから渡す。"
  (let ((user-obj (if (typep user-id 'user)
                      user-id
                      ;; IDの場合はuserオブジェクトを取得
                      (voro.model.user:find-user-by-id user-id))))
    (unless user-obj
      (error "User not found for id: ~A" user-id))
    (mito:create-dao 'post
                     :user user-obj
                     :title title
                     :content content
                     :published published)))

;;; JSON変換

(defun format-timestamp (timestamp)
  "タイムスタンプをISO8601形式の文字列に変換"
  (when timestamp
    (format-timestring nil timestamp :format +iso-8601-format+)))

(defun post-to-alist (post)
  "投稿をalist形式に変換（JSONレスポンス用）"
  (list (cons :|id| (post-id post))
        (cons :|user_id| (post-user-id post))
        (cons :|title| (post-title post))
        (cons :|content| (post-content post))
        (cons :|published| (post-published post))
        (cons :|created_at| (format-timestamp (post-created-at post)))
        (cons :|updated_at| (format-timestamp (post-updated-at post)))))
