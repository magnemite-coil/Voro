(defpackage voro.test.handler.post
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment
                :with-test-db)
  (:import-from :voro.test.http-helper
                :with-test-server
                :http-post
                :http-get
                :http-put
                :http-delete
                :assert-status
                :assert-json-response
                :with-authenticated-user)
  (:import-from :voro.test.fixtures
                :create-test-user
                :create-test-session))

(in-package :voro.test.handler.post)

;;; POST /api/posts - 投稿作成

(deftest post-create-success-test
  (testing "POST /api/posts - 投稿作成成功（公開投稿）"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            (multiple-value-bind (body status headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Test Title")
                                     (cons :|content| "Test Content")
                                     (cons :|published| t))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore headers))
              (assert-status 201 status)
              (assert-json-response body "data" "post" "id")
              (assert-json-response body "data" "post" "title")
              (assert-json-response body "data" "post" "content"))))))))

(deftest post-create-draft-test
  (testing "POST /api/posts - 下書き投稿作成（published未指定）"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            (multiple-value-bind (body status headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Draft Title")
                                     (cons :|content| "Draft Content"))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore headers))
              (assert-status 201 status)
              (assert-json-response body "data" "post" "id"))))))))

(deftest post-create-unauthorized-test
  (testing "POST /api/posts - 未認証エラー"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-post "/api/posts"
                        :json (list (cons :|title| "Test Title")
                                   (cons :|content| "Test Content")))
            (declare (ignore body headers))
            (assert-status 401 status)))))))

(deftest post-create-validation-error-test
  (testing "POST /api/posts - バリデーションエラー（タイトルなし）"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            (multiple-value-bind (body status headers)
                (http-post "/api/posts"
                          :json (list (cons :|content| "Content only"))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore body headers))
              (assert-status 400 status))))))))

;;; GET /api/posts - 公開投稿一覧

(deftest post-list-test
  (testing "GET /api/posts - 公開投稿一覧取得"
    (with-test-environment
      (with-test-server
        (with-test-db
          ;; テスト投稿を作成
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            (http-post "/api/posts"
                      :json (list (cons :|title| "Public Post 1")
                                 (cons :|content| "Content 1")
                                 (cons :|published| t))
                      :cookies (list (cons "session_id" session-id)))
            (http-post "/api/posts"
                      :json (list (cons :|title| "Public Post 2")
                                 (cons :|content| "Content 2")
                                 (cons :|published| t))
                      :cookies (list (cons "session_id" session-id))))

          ;; 一覧取得（認証不要）
          (multiple-value-bind (body status headers)
              (http-get "/api/posts")
            (declare (ignore headers))
            (assert-status 200 status)
            (assert-json-response body "data" "posts")
            (assert-json-response body "data" "pagination")))))))

;;; GET /api/posts/:id - 投稿詳細

(deftest post-get-published-test
  (testing "GET /api/posts/:id - 公開投稿取得"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            ;; 投稿作成
            (multiple-value-bind (create-body create-status create-headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Public Post")
                                     (cons :|content| "Content")
                                     (cons :|published| t))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore create-status create-headers))
              ;; IDを抽出
              (let* ((parsed (com.inuoe.jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; 認証なしで取得可能
                (multiple-value-bind (body status headers)
                    (http-get (format nil "/api/posts/~D" post-id))
                  (declare (ignore headers))
                  (assert-status 200 status)
                  (assert-json-response body "data" "post" "title"))))))))))

(deftest post-get-draft-owner-test
  (testing "GET /api/posts/:id - 下書き投稿取得（所有者）"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            ;; 下書き投稿作成
            (multiple-value-bind (create-body create-status create-headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Draft Post")
                                     (cons :|content| "Content")
                                     (cons :|published| nil))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore create-status create-headers))
              (let* ((parsed (com.inuoe.jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; 所有者として取得可能
                (multiple-value-bind (body status headers)
                    (http-get (format nil "/api/posts/~D" post-id)
                             :cookies (list (cons "session_id" session-id)))
                  (declare (ignore headers))
                  (assert-status 200 status)
                  (assert-json-response body "data" "post" "title"))))))))))

(deftest post-get-draft-non-owner-test
  (testing "GET /api/posts/:id - 下書き投稿取得（非所有者）→404"
    (with-test-environment
      (with-test-server
        (with-test-db
          ;; ユーザー1が下書き作成
          (multiple-value-bind (session-id1 user1)
              (create-test-session)
            (declare (ignore user1))
            (multiple-value-bind (create-body create-status create-headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Draft Post")
                                     (cons :|content| "Content")
                                     (cons :|published| nil))
                          :cookies (list (cons "session_id" session-id1)))
              (declare (ignore create-status create-headers))
              (let* ((parsed (com.inuoe.jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; ユーザー2として取得試行
                (multiple-value-bind (session-id2 user2)
                    (create-test-session)
                  (declare (ignore user2))
                  (multiple-value-bind (body status headers)
                      (http-get (format nil "/api/posts/~D" post-id)
                               :cookies (list (cons "session_id" session-id2)))
                    (declare (ignore body headers))
                    (assert-status 404 status)))))))))))

;;; PUT /api/posts/:id - 投稿更新

(deftest post-update-success-test
  (testing "PUT /api/posts/:id - 投稿更新成功"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            ;; 投稿作成
            (multiple-value-bind (create-body create-status create-headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Original Title")
                                     (cons :|content| "Original Content"))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore create-status create-headers))
              (let* ((parsed (com.inuoe.jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; 更新
                (multiple-value-bind (body status headers)
                    (http-put (format nil "/api/posts/~D" post-id)
                             :json (list (cons :|title| "Updated Title"))
                             :cookies (list (cons "session_id" session-id)))
                  (declare (ignore headers))
                  (assert-status 200 status)
                  (assert-json-response body "data" "post" "title"))))))))))

(deftest post-update-publish-test
  (testing "PUT /api/posts/:id - 下書きを公開に変更"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            ;; 下書き作成
            (multiple-value-bind (create-body create-status create-headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Draft")
                                     (cons :|content| "Content")
                                     (cons :|published| nil))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore create-status create-headers))
              (let* ((parsed (com.inuoe.jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; 公開に変更
                (multiple-value-bind (body status headers)
                    (http-put (format nil "/api/posts/~D" post-id)
                             :json (list (cons :|published| t))
                             :cookies (list (cons "session_id" session-id)))
                  (declare (ignore headers))
                  (assert-status 200 status)
                  (assert-json-response body "data" "post"))))))))))

(deftest post-update-unpublish-test
  (testing "PUT /api/posts/:id - 公開投稿を非公開に変更"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            ;; 公開投稿を作成
            (multiple-value-bind (create-body create-status create-headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Public Post")
                                     (cons :|content| "Content")
                                     (cons :|published| t))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore create-status create-headers))
              (let* ((parsed (com.inuoe.jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; 非公開に変更（published: false）
                (multiple-value-bind (body status headers)
                    (http-put (format nil "/api/posts/~D" post-id)
                             :json (list (cons :|published| nil))
                             :cookies (list (cons "session_id" session-id)))
                  (declare (ignore headers))
                  (assert-status 200 status)
                  ;; publishedがfalseになっていることを確認
                  (let* ((result (com.inuoe.jzon:parse body))
                         (post (gethash "post" (gethash "data" result)))
                         (published (gethash "published" post)))
                    (ok (null published) "published should be false")))))))))))

(deftest post-update-no-publish-change-test
  (testing "PUT /api/posts/:id - publishedキーなしで更新（publishedは変更されない）"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            ;; 公開投稿を作成
            (multiple-value-bind (create-body create-status create-headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Original Title")
                                     (cons :|content| "Original Content")
                                     (cons :|published| t))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore create-status create-headers))
              (let* ((parsed (com.inuoe.jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; タイトルのみ更新（publishedキーなし）
                (multiple-value-bind (body status headers)
                    (http-put (format nil "/api/posts/~D" post-id)
                             :json (list (cons :|title| "Updated Title"))
                             :cookies (list (cons "session_id" session-id)))
                  (declare (ignore headers))
                  (assert-status 200 status)
                  ;; publishedがtrueのままであることを確認
                  (let* ((result (com.inuoe.jzon:parse body))
                         (post (gethash "post" (gethash "data" result)))
                         (published (gethash "published" post))
                         (title (gethash "title" post)))
                    (ok (eq published t) "published should remain true")
                    (ok (string= title "Updated Title") "title should be updated")))))))))))

(deftest post-update-forbidden-test
  (testing "PUT /api/posts/:id - 他人の投稿更新→403"
    (with-test-environment
      (with-test-server
        (with-test-db
          ;; ユーザー1が投稿作成
          (multiple-value-bind (session-id1 user1)
              (create-test-session)
            (declare (ignore user1))
            (multiple-value-bind (create-body create-status create-headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Original")
                                     (cons :|content| "Content"))
                          :cookies (list (cons "session_id" session-id1)))
              (declare (ignore create-status create-headers))
              (let* ((parsed (com.inuoe.jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; ユーザー2として更新試行
                (multiple-value-bind (session-id2 user2)
                    (create-test-session)
                  (declare (ignore user2))
                  (multiple-value-bind (body status headers)
                      (http-put (format nil "/api/posts/~D" post-id)
                               :json (list (cons :|title| "Hacked"))
                               :cookies (list (cons "session_id" session-id2)))
                    (declare (ignore body headers))
                    (assert-status 403 status)))))))))))

;;; DELETE /api/posts/:id - 投稿削除

(deftest post-delete-success-test
  (testing "DELETE /api/posts/:id - 投稿削除成功"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            ;; 投稿作成
            (multiple-value-bind (create-body create-status create-headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "ToDelete")
                                     (cons :|content| "Content"))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore create-status create-headers))
              (let* ((parsed (com.inuoe.jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; 削除
                (multiple-value-bind (body status headers)
                    (http-delete (format nil "/api/posts/~D" post-id)
                                :cookies (list (cons "session_id" session-id)))
                  (declare (ignore headers))
                  (assert-status 200 status)
                  (assert-json-response body "data" "message"))
                ;; 削除後は取得不可
                (multiple-value-bind (body status headers)
                    (http-get (format nil "/api/posts/~D" post-id)
                             :cookies (list (cons "session_id" session-id)))
                  (declare (ignore body headers))
                  (assert-status 404 status))))))))))

(deftest post-delete-forbidden-test
  (testing "DELETE /api/posts/:id - 他人の投稿削除→403"
    (with-test-environment
      (with-test-server
        (with-test-db
          ;; ユーザー1が投稿作成
          (multiple-value-bind (session-id1 user1)
              (create-test-session)
            (declare (ignore user1))
            (multiple-value-bind (create-body create-status create-headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Original")
                                     (cons :|content| "Content"))
                          :cookies (list (cons "session_id" session-id1)))
              (declare (ignore create-status create-headers))
              (let* ((parsed (com.inuoe.jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; ユーザー2として削除試行
                (multiple-value-bind (session-id2 user2)
                    (create-test-session)
                  (declare (ignore user2))
                  (multiple-value-bind (body status headers)
                      (http-delete (format nil "/api/posts/~D" post-id)
                                  :cookies (list (cons "session_id" session-id2)))
                    (declare (ignore body headers))
                    (assert-status 403 status)))))))))))

;;; GET /api/users/:user_id/posts - 特定ユーザーの公開投稿一覧

(deftest user-posts-test
  (testing "GET /api/users/:user_id/posts - 特定ユーザーの公開投稿一覧"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (let ((user-id (voro.model.user:user-id user)))
              ;; 投稿作成
              (http-post "/api/posts"
                        :json (list (cons :|title| "Public")
                                   (cons :|content| "Content")
                                   (cons :|published| t))
                        :cookies (list (cons "session_id" session-id)))
              (http-post "/api/posts"
                        :json (list (cons :|title| "Draft")
                                   (cons :|content| "Content")
                                   (cons :|published| nil))
                        :cookies (list (cons "session_id" session-id)))

              ;; 公開投稿のみ取得される
              (multiple-value-bind (body status headers)
                  (http-get (format nil "/api/users/~D/posts" user-id))
                (declare (ignore headers))
                (assert-status 200 status)
                (assert-json-response body "data" "posts")
                (assert-json-response body "data" "pagination")))))))))

(deftest user-posts-not-found-test
  (testing "GET /api/users/:user_id/posts - 存在しないユーザー→404"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-get "/api/users/999999/posts")
            (declare (ignore body headers))
            (assert-status 404 status)))))))

;;; GET /api/me/posts - 自分の投稿一覧

(deftest my-posts-test
  (testing "GET /api/me/posts - 自分の投稿一覧（全件）"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            ;; 投稿作成
            (http-post "/api/posts"
                      :json (list (cons :|title| "My Public")
                                 (cons :|content| "Content")
                                 (cons :|published| t))
                      :cookies (list (cons "session_id" session-id)))
            (http-post "/api/posts"
                      :json (list (cons :|title| "My Draft")
                                 (cons :|content| "Content")
                                 (cons :|published| nil))
                      :cookies (list (cons "session_id" session-id)))

            ;; 全件取得
            (multiple-value-bind (body status headers)
                (http-get "/api/me/posts"
                         :cookies (list (cons "session_id" session-id)))
              (declare (ignore headers))
              (assert-status 200 status)
              (assert-json-response body "data" "posts")
              (assert-json-response body "data" "pagination"))))))))

(deftest my-posts-filter-published-test
  (testing "GET /api/me/posts?published=true - 公開投稿のみ"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            ;; 投稿作成
            (http-post "/api/posts"
                      :json (list (cons :|title| "Public Only")
                                 (cons :|content| "Content")
                                 (cons :|published| t))
                      :cookies (list (cons "session_id" session-id)))
            (http-post "/api/posts"
                      :json (list (cons :|title| "Draft Only")
                                 (cons :|content| "Content")
                                 (cons :|published| nil))
                      :cookies (list (cons "session_id" session-id)))

            ;; 公開のみ取得
            (multiple-value-bind (body status headers)
                (http-get "/api/me/posts?published=true"
                         :cookies (list (cons "session_id" session-id)))
              (declare (ignore headers))
              (assert-status 200 status)
              (assert-json-response body "data" "posts"))))))))

(deftest my-posts-filter-draft-test
  (testing "GET /api/me/posts?published=false - 非公開投稿のみ"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            ;; 投稿作成
            (http-post "/api/posts"
                      :json (list (cons :|title| "Public Only")
                                 (cons :|content| "Content")
                                 (cons :|published| t))
                      :cookies (list (cons "session_id" session-id)))
            (http-post "/api/posts"
                      :json (list (cons :|title| "Draft Only")
                                 (cons :|content| "Content")
                                 (cons :|published| nil))
                      :cookies (list (cons "session_id" session-id)))

            ;; 非公開のみ取得
            (multiple-value-bind (body status headers)
                (http-get "/api/me/posts?published=false"
                         :cookies (list (cons "session_id" session-id)))
              (declare (ignore headers))
              (assert-status 200 status)
              (assert-json-response body "data" "posts"))))))))

(deftest my-posts-unauthorized-test
  (testing "GET /api/me/posts - 未認証エラー"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-get "/api/me/posts")
            (declare (ignore body headers))
            (assert-status 401 status)))))))

;;;
;;; ページネーション境界値テスト（HTTP統合）
;;;

(deftest post-list-pagination-edge-cases-test
  (testing "GET /api/posts - page=0は1に正規化される"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-get "/api/posts?page=0")
            (declare (ignore headers))
            (assert-status 200 status)
            (let* ((parsed (com.inuoe.jzon:parse body))
                   (pagination (gethash "pagination" (gethash "data" parsed))))
              (ok (= (gethash "page" pagination) 1)
                  "page should be normalized to 1")))))))

  (testing "GET /api/posts - per_page=200は100に正規化される"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-get "/api/posts?per_page=200")
            (declare (ignore headers))
            (assert-status 200 status)
            (let* ((parsed (com.inuoe.jzon:parse body))
                   (pagination (gethash "pagination" (gethash "data" parsed))))
              (ok (= (gethash "per_page" pagination) 100)
                  "per_page should be capped at 100")))))))

  (testing "GET /api/posts - 投稿0件の場合は空配列"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-get "/api/posts")
            (declare (ignore headers))
            (assert-status 200 status)
            (let* ((parsed (com.inuoe.jzon:parse body))
                   (posts (gethash "posts" (gethash "data" parsed))))
              (ok (zerop (length posts))
                  "posts should be empty array")))))))

  (testing "GET /api/posts - page=10001は10000に正規化される"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-get "/api/posts?page=10001")
            (declare (ignore headers))
            (assert-status 200 status)
            (let* ((parsed (com.inuoe.jzon:parse body))
                   (pagination (gethash "pagination" (gethash "data" parsed))))
              (ok (= (gethash "page" pagination) 10000)
                  "page should be capped at 10000"))))))))

;;;
;;; 不正なID入力テスト
;;;

(deftest post-get-invalid-id-test
  (testing "GET /api/posts/:id - 不正なID（文字列）は400"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-get "/api/posts/abc")
            (declare (ignore body headers))
            (assert-status 400 status))))))

  (testing "GET /api/posts/:id - 不正なID（小数）は400"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-get "/api/posts/1.5")
            (declare (ignore body headers))
            (assert-status 400 status))))))

  (testing "GET /api/posts/:id - 存在しない大きなIDは404"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-get "/api/posts/9999999999")
            (declare (ignore body headers))
            (assert-status 404 status)))))))

;;;
;;; 投稿作成境界値テスト（HTTP統合）
;;;

(deftest post-create-edge-cases-test
  (testing "POST /api/posts - 境界値タイトル（1文字）"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            (multiple-value-bind (body status headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "A")
                                     (cons :|content| "Valid content"))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore headers))
              (assert-status 201 status)
              (let* ((parsed (com.inuoe.jzon:parse body))
                     (post (gethash "post" (gethash "data" parsed))))
                (ok (string= (gethash "title" post) "A")
                    "Title should be 'A'"))))))))

  (testing "POST /api/posts - 境界値タイトル（200文字）"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            (let ((title-200 (make-string 200 :initial-element #\T)))
              (multiple-value-bind (body status headers)
                  (http-post "/api/posts"
                            :json (list (cons :|title| title-200)
                                       (cons :|content| "Valid content"))
                            :cookies (list (cons "session_id" session-id)))
                (declare (ignore headers))
                (assert-status 201 status)
                (let* ((parsed (com.inuoe.jzon:parse body))
                       (post (gethash "post" (gethash "data" parsed))))
                  (ok (= (length (gethash "title" post)) 200)
                      "Title should be 200 characters")))))))))

  (testing "POST /api/posts - タイトル超過（201文字）は400"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            (let ((title-201 (make-string 201 :initial-element #\T)))
              (multiple-value-bind (body status headers)
                  (http-post "/api/posts"
                            :json (list (cons :|title| title-201)
                                       (cons :|content| "Valid content"))
                            :cookies (list (cons "session_id" session-id)))
                (declare (ignore body headers))
                (assert-status 400 status))))))))

  (testing "POST /api/posts - XSS文字列はそのまま保存される"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            (let ((xss-title "<script>alert('xss')</script>"))
              (multiple-value-bind (body status headers)
                  (http-post "/api/posts"
                            :json (list (cons :|title| xss-title)
                                       (cons :|content| "Content"))
                            :cookies (list (cons "session_id" session-id)))
                (declare (ignore headers))
                (assert-status 201 status)
                (let* ((parsed (com.inuoe.jzon:parse body))
                       (post (gethash "post" (gethash "data" parsed))))
                  (ok (string= (gethash "title" post) xss-title)
                      "XSS string should be stored as-is"))))))))))
