(defpackage voro.service.post
  (:use :cl)
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
                :count-user-posts-this-month
                :create-post)
  (:import-from :voro.util.log
                :log-info
                :log-error)
  (:import-from :voro.util.validation
                :validation-error
                :authorization-error
                :not-found-error)
  (:export
   :create-new-post
   :get-post
   :update-post
   :delete-post
   :list-published-posts
   :list-user-posts
   :list-my-posts
   :get-user-post-stats))

(in-package :voro.service.post)

;;; バリデーション定数

(defconstant +title-min-length+ 1)
(defconstant +title-max-length+ 200)
(defconstant +content-min-length+ 1)
(defconstant +content-max-length+ 100000)  ; 約100KB（DoS対策）
(defconstant +per-page-max+ 100)
(defconstant +per-page-default+ 20)
(defconstant +page-max+ 10000)  ; ページ上限（DoS対策）

;;; バリデーション関数

(defun validate-title (title)
  "タイトルのバリデーション
   注意: 空白のみのタイトルは許可しない"
  (cond
    ((null title)
     (error 'validation-error :message "Title is required"))
    ((zerop (length (string-trim '(#\Space #\Tab #\Newline #\Return) title)))
     (error 'validation-error :message "Title cannot be empty or whitespace only"))
    ((> (length title) +title-max-length+)
     (error 'validation-error
            :message (format nil "Title must not exceed ~D characters" +title-max-length+)))))

(defun validate-content (content)
  "本文のバリデーション
   注意: 空白のみの本文は許可しない"
  (cond
    ((null content)
     (error 'validation-error :message "Content is required"))
    ((zerop (length (string-trim '(#\Space #\Tab #\Newline #\Return) content)))
     (error 'validation-error :message "Content cannot be empty or whitespace only"))
    ((> (length content) +content-max-length+)
     (error 'validation-error
            :message (format nil "Content must not exceed ~D characters" +content-max-length+)))))

(defun normalize-pagination (page per-page)
  "ページネーションパラメータを正規化
   page: 1 ～ +page-max+ に制限（DoS対策）
   per-page: 1 ～ +per-page-max+ に制限"
  (let ((normalized-page (min +page-max+ (max 1 (or page 1))))
        (normalized-per-page (min +per-page-max+
                                  (max 1 (or per-page +per-page-default+)))))
    (values normalized-page normalized-per-page)))

;;; サービス関数

(defun create-new-post (user-id title content &key (published nil))
  "新規投稿を作成"
  (validate-title title)
  (validate-content content)

  (handler-case
      (let ((post (create-post user-id title content :published published)))
        (log-info "Post created"
                  :context (list :|user_id| user-id
                                 :|post_id| (post-id post)
                                 :|published| published))
        post)
    (error (e)
      (log-error "Failed to create post"
                 :error e
                 :context (list :|user_id| user-id))
      (error e))))

(defun get-post (post-id &key session-user-id)
  "投稿を取得（権限チェック付き）
   - 公開投稿: 誰でも閲覧可能
   - 非公開投稿: 投稿者本人のみ閲覧可能"
  (let ((post (find-post-by-id post-id)))
    (cond
      ((null post) nil)
      ((post-published post) post)
      ((and session-user-id (= (post-user-id post) session-user-id)) post)
      (t nil))))  ; 非公開投稿で権限なし

(defun update-post (post-id user-id &key title content (published :not-specified))
  "投稿を更新（所有権チェック付き）
   published: :not-specified（未指定）、t（公開）、nil（非公開）"
  (let ((post (find-post-by-id post-id)))
    (unless post
      (error 'not-found-error :message "Post not found"))

    ;; 所有権チェック
    (unless (= (post-user-id post) user-id)
      (log-info "Unauthorized update attempt"
                :context (list :|post_id| post-id
                               :|owner_id| (post-user-id post)
                               :|requester_id| user-id))
      (error 'authorization-error :message "Not authorized to update this post"))

    ;; バリデーション（指定されたフィールドのみ）
    (when title (validate-title title))
    (when content (validate-content content))

    ;; 更新
    (when title (setf (post-title post) title))
    (when content (setf (post-content post) content))
    (unless (eq published :not-specified)
      (setf (post-published post) published))

    (mito:save-dao post)  ; Mito関数は完全修飾で呼び出し（既存パターン踏襲）
    (log-info "Post updated"
              :context (list :|post_id| post-id
                             :|user_id| user-id))
    post))

(defun delete-post (post-id user-id)
  "投稿を削除（所有権チェック付き）"
  (let ((post (find-post-by-id post-id)))
    (unless post
      (error 'not-found-error :message "Post not found"))

    ;; 所有権チェック
    (unless (= (post-user-id post) user-id)
      (log-info "Unauthorized delete attempt"
                :context (list :|post_id| post-id
                               :|owner_id| (post-user-id post)
                               :|requester_id| user-id))
      (error 'authorization-error :message "Not authorized to delete this post"))

    (mito:delete-dao post)  ; Mito関数は完全修飾で呼び出し
    (log-info "Post deleted"
              :context (list :|post_id| post-id
                             :|user_id| user-id))
    t))

(defun list-published-posts (&key (page 1) (per-page 20))
  "公開投稿一覧を取得"
  (multiple-value-bind (norm-page norm-per-page) (normalize-pagination page per-page)
    (let* ((offset (* (1- norm-page) norm-per-page))
           (posts (find-published-posts :limit norm-per-page :offset offset))
           (total (count-published-posts)))
      (values posts
              (list (cons :|page| norm-page)
                    (cons :|per_page| norm-per-page)
                    (cons :|total_count| total)
                    (cons :|total_pages| (if (zerop total) 0 (ceiling total norm-per-page))))))))

(defun list-user-posts (user-id &key (page 1) (per-page 20))
  "特定ユーザーの公開投稿一覧を取得"
  (multiple-value-bind (norm-page norm-per-page) (normalize-pagination page per-page)
    (let* ((offset (* (1- norm-page) norm-per-page))
           (posts (find-posts-by-user-id user-id :published t
                                                  :limit norm-per-page
                                                  :offset offset))
           (total (count-user-posts user-id :published t)))
      (values posts
              (list (cons :|page| norm-page)
                    (cons :|per_page| norm-per-page)
                    (cons :|total_count| total)
                    (cons :|total_pages| (if (zerop total) 0 (ceiling total norm-per-page))))))))

(defun list-my-posts (user-id &key (page 1) (per-page 20) (published :all))
  "自分の投稿一覧を取得（下書き含む）
   published: :all（全件）、t（公開のみ）、nil（非公開のみ）"
  (multiple-value-bind (norm-page norm-per-page) (normalize-pagination page per-page)
    (let* ((offset (* (1- norm-page) norm-per-page))
           (posts (find-posts-by-user-id user-id
                                          :published published
                                          :limit norm-per-page
                                          :offset offset))
           (total (count-user-posts user-id :published published)))
      (values posts
              (list (cons :|page| norm-page)
                    (cons :|per_page| norm-per-page)
                    (cons :|total_count| total)
                    (cons :|total_pages| (if (zerop total) 0 (ceiling total norm-per-page))))))))

(defun get-user-post-stats (user-id)
  "ユーザーの投稿統計を取得
   戻り値: alist形式の統計情報
     - total: 全投稿数
     - published: 公開中の投稿数
     - draft: 下書きの投稿数
     - this_month: 今月作成された投稿数"
  (list (cons :|total| (count-user-posts user-id :published :all))
        (cons :|published| (count-user-posts user-id :published t))
        (cons :|draft| (count-user-posts user-id :published nil))
        (cons :|this_month| (count-user-posts-this-month user-id))))
