(defpackage voro.handler.post
  (:use :cl :caveman2)
  (:import-from :voro.web
                :*app*)
  (:import-from :voro.service.post
                :create-new-post
                :get-post
                :update-post
                :delete-post
                :list-published-posts
                :list-user-posts
                :list-my-posts)
  (:import-from :voro.model.post
                :post-to-alist)
  (:import-from :voro.model.user
                :find-user-by-id)
  (:import-from :voro.middleware.session
                :get-session-user-id)
  (:import-from :voro.util.response
                :response-success
                :response-error)
  (:import-from :voro.util.log
                :log-error)
  (:import-from :voro.util.validation
                :validation-error
                :validation-error-message
                :authorization-error
                :not-found-error
                :not-found-error-message)
  (:import-from :voro.util.request
                :get-body-param))
;; 注意: authorization-error-message は現在未使用（403では固定メッセージ "Forbidden" を返す）

(in-package :voro.handler.post)

;;; ヘルパー関数
;;; get-request-body-param は voro.util.request に共通化済み。
;;; 以下の関数は post.lisp 固有（他のハンドラーで必要になった時点で共通化を検討）:
;;; - get-query-param
;;; - parse-integer-param
;;; - get-current-user-id
;;;
;;; JSONパース: Lack の http-body ミドルウェア（内部でYason使用）がJSONリクエストを自動的にパースする。
;;; パース結果は文字列キーのalistとして request-body-parameters に格納される。
;;; （例: "title" → "投稿タイトル", "published" → t または nil）
;;; 注意: JSONのboolean値（true/false）はYasonによりLispの t/nil に変換される（文字列ではない）

(defun get-request-body-param (key)
  "リクエストボディからパラメータを取得（共通ユーティリティのラッパー）"
  (get-body-param (lack.request:request-body-parameters *request*) key))

(defun get-query-param (key &optional default)
  "クエリパラメータを取得（post.lisp で新規追加）"
  (or (cdr (assoc key (lack.request:request-query-parameters *request*) :test #'string=))
      default))

(defun parse-integer-param (value &optional default)
  "パラメータを整数に変換（post.lisp で新規追加）"
  (if value
      (handler-case (parse-integer value)
        (error () default))
      default))

(defun get-current-user-id ()
  "現在のセッションからuser_idを取得
   既存のauth.lispと同じパターンを使用"
  (let* ((cookies (lack.request:request-cookies *request*))
         (session-id (cdr (assoc "session_id" cookies :test #'string=))))
    (when session-id
      (get-session-user-id session-id))))

(defun posts-to-json (posts)
  "投稿リストをJSON用形式に変換"
  (map 'list #'post-to-alist posts))

;;; ルート定義

;; 投稿作成
(defroute (*app* "/api/posts" :method :POST) ()
  (let ((user-id (get-current-user-id)))
    ;; 認証チェック
    (if (not user-id)
        (response-error 401 "Authentication required")

        ;; 認証済み
        (let ((title (get-request-body-param "title"))
              (content (get-request-body-param "content"))
              (published (get-request-body-param "published")))

          ;; 入力検証
          (if (not (and title content))
              (response-error 400 "Title and content are required")

              ;; 投稿作成
              ;; 注意: published は http-body（内部でYason使用）により t/nil として受け取る（文字列ではない）
              (handler-case
                  (let ((post (create-new-post user-id title content
                                                :published (eq published t))))
                    (response-success
                     (list (cons :|post| (post-to-alist post)))
                     :status 201))

                (validation-error (e)
                  (response-error 400 (validation-error-message e)))

                (error (e)
                  (let ((error-id (log-error "Failed to create post" :error e)))
                    (response-error 500 "Internal server error" :error-id error-id)))))))))

;; 公開投稿一覧取得
(defroute (*app* "/api/posts" :method :GET) ()
  (let ((page (parse-integer-param (get-query-param "page") 1))
        (per-page (parse-integer-param (get-query-param "per_page") 20)))

    (handler-case
        (multiple-value-bind (posts pagination)
            (list-published-posts :page page :per-page per-page)
          (response-success
           (list (cons :|posts| (posts-to-json posts))
                 (cons :|pagination| pagination))))

      (error (e)
        (let ((error-id (log-error "Failed to list posts" :error e)))
          (response-error 500 "Internal server error" :error-id error-id))))))

;; 投稿詳細取得
(defroute (*app* "/api/posts/:id" :method :GET) (&key id)
  (let ((post-id (parse-integer-param id))
        (user-id (get-current-user-id)))

    (if (not post-id)
        (response-error 400 "Invalid post ID")

        (handler-case
            (let ((post (get-post post-id :session-user-id user-id)))
              (if post
                  (response-success (list (cons :|post| (post-to-alist post))))
                  (response-error 404 "Post not found")))

          (error (e)
            (let ((error-id (log-error "Failed to get post" :error e)))
              (response-error 500 "Internal server error" :error-id error-id)))))))

;; 投稿更新
(defroute (*app* "/api/posts/:id" :method :PUT) (&key id)
  (let ((user-id (get-current-user-id)))
    ;; 認証チェック
    (if (not user-id)
        (response-error 401 "Authentication required")

        (let* ((post-id (parse-integer-param id))
               (title (get-request-body-param "title"))
               (content (get-request-body-param "content"))
               (body-params (lack.request:request-body-parameters *request*))
               (published-entry (assoc "published" body-params :test #'string=)))

          (if (not post-id)
              (response-error 400 "Invalid post ID")

              ;; published パラメータの変換
              ;; 注意: http-body（内部でYason使用）により t/nil として受け取る（文字列ではない）
              ;; JSONにキーが存在するかで「未指定」と「false」を区別する
              ;; - キーなし（assoc が nil）: :not-specified
              ;; - キーあり、値が t: t
              ;; - キーあり、値が nil（JSON の false）: nil
              (let ((published (cond
                                 ((null published-entry) :not-specified)
                                 ((eq (cdr published-entry) t) t)
                                 (t nil))))

                (handler-case
                    (let ((post (update-post post-id user-id
                                              :title title
                                              :content content
                                              :published published)))
                      (response-success (list (cons :|post| (post-to-alist post)))))

                  (not-found-error (e)
                    (response-error 404 (not-found-error-message e)))

                  (validation-error (e)
                    (response-error 400 (validation-error-message e)))

                  (authorization-error (e)
                    (declare (ignore e))
                    (response-error 403 "Forbidden"))

                  (error (e)
                    (let ((error-id (log-error "Failed to update post" :error e)))
                      (response-error 500 "Internal server error" :error-id error-id))))))))))

;; 投稿削除
(defroute (*app* "/api/posts/:id" :method :DELETE) (&key id)
  (let ((user-id (get-current-user-id)))
    ;; 認証チェック
    (if (not user-id)
        (response-error 401 "Authentication required")

        (let ((post-id (parse-integer-param id)))
          (if (not post-id)
              (response-error 400 "Invalid post ID")

              (handler-case
                  (progn
                    (delete-post post-id user-id)
                    (response-success (list (cons :|message| "Post deleted successfully"))))

                (not-found-error (e)
                  (response-error 404 (not-found-error-message e)))

                (authorization-error (e)
                  (declare (ignore e))
                  (response-error 403 "Forbidden"))

                (error (e)
                  (let ((error-id (log-error "Failed to delete post" :error e)))
                    (response-error 500 "Internal server error" :error-id error-id)))))))))

;; 特定ユーザーの公開投稿一覧
(defroute (*app* "/api/users/:user_id/posts" :method :GET) (&key user_id)
  (let ((target-user-id (parse-integer-param user_id))
        (page (parse-integer-param (get-query-param "page") 1))
        (per-page (parse-integer-param (get-query-param "per_page") 20)))

    (if (not target-user-id)
        (response-error 400 "Invalid user ID")

        ;; ユーザーの存在確認
        (if (not (find-user-by-id target-user-id))
            (response-error 404 "User not found")

            (handler-case
                (multiple-value-bind (posts pagination)
                    (list-user-posts target-user-id :page page :per-page per-page)
                  (response-success
                   (list (cons :|posts| (posts-to-json posts))
                         (cons :|pagination| pagination))))

              (error (e)
                (let ((error-id (log-error "Failed to list user posts" :error e)))
                  (response-error 500 "Internal server error" :error-id error-id))))))))

;; 自分の投稿一覧
(defroute (*app* "/api/me/posts" :method :GET) ()
  (let ((user-id (get-current-user-id)))
    ;; 認証チェック
    (if (not user-id)
        (response-error 401 "Authentication required")

        (let ((page (parse-integer-param (get-query-param "page") 1))
              (per-page (parse-integer-param (get-query-param "per_page") 20))
              (published-param (get-query-param "published")))

          ;; published パラメータの変換
          ;; 未指定: :all, "true": t, "false": nil
          (let ((published (cond
                             ((null published-param) :all)
                             ((string= published-param "true") t)
                             ((string= published-param "false") nil)
                             (t :all))))

            (handler-case
                (multiple-value-bind (posts pagination)
                    (list-my-posts user-id :page page :per-page per-page :published published)
                  (response-success
                   (list (cons :|posts| (posts-to-json posts))
                         (cons :|pagination| pagination))))

              (error (e)
                (let ((error-id (log-error "Failed to list my posts" :error e)))
                  (response-error 500 "Internal server error" :error-id error-id)))))))))
