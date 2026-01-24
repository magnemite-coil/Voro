(defpackage voro.test.handler.post-direct
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment
                :with-test-db)
  (:import-from :voro.test.direct-call-helper
                :direct-get
                :direct-post
                :direct-put
                :direct-delete
                :assert-direct-status
                :assert-direct-json
                :assert-direct-json-value
                :extract-session-id)
  (:import-from :voro.test.fixtures
                :create-test-user
                :create-test-session)
  (:local-nicknames (:jzon :com.inuoe.jzon)))

(in-package :voro.test.handler.post-direct)

;;;
;;; POST /api/posts - 投稿作成（直接呼び出し）
;;;

(deftest post-create-direct-success-test
  (testing "POST /api/posts - 投稿作成成功（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          (multiple-value-bind (body status headers)
              (direct-post "/api/posts"
                          :json (list (cons :|title| "Test Title")
                                     (cons :|content| "Test Content")
                                     (cons :|published| t))
                          :cookies (list (cons "session_id" session-id)))
            (declare (ignore headers))
            (assert-direct-status 201 status)
            (assert-direct-json body "data" "post" "id")
            (assert-direct-json body "data" "post" "title")
            (assert-direct-json body "data" "post" "content")))))))

(deftest post-create-direct-draft-test
  (testing "POST /api/posts - 下書き投稿作成（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          (multiple-value-bind (body status headers)
              (direct-post "/api/posts"
                          :json (list (cons :|title| "Draft Title")
                                     (cons :|content| "Draft Content"))
                          :cookies (list (cons "session_id" session-id)))
            (declare (ignore headers))
            (assert-direct-status 201 status)
            (assert-direct-json body "data" "post" "id")))))))

(deftest post-create-direct-unauthorized-test
  (testing "POST /api/posts - 未認証エラー（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (body status headers)
            (direct-post "/api/posts"
                        :json (list (cons :|title| "Test Title")
                                   (cons :|content| "Test Content")))
          (declare (ignore body headers))
          (assert-direct-status 401 status))))))

(deftest post-create-direct-validation-error-test
  (testing "POST /api/posts - バリデーションエラー（タイトルなし）（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          (multiple-value-bind (body status headers)
              (direct-post "/api/posts"
                          :json (list (cons :|content| "Content only"))
                          :cookies (list (cons "session_id" session-id)))
            (declare (ignore body headers))
            (assert-direct-status 400 status)))))))

;;;
;;; GET /api/posts - 公開投稿一覧（直接呼び出し）
;;;

(deftest post-list-direct-test
  (testing "GET /api/posts - 公開投稿一覧取得（直接呼び出し）"
    (with-test-environment
      (with-test-db
        ;; テスト投稿を作成
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          (direct-post "/api/posts"
                      :json (list (cons :|title| "Public Post 1")
                                 (cons :|content| "Content 1")
                                 (cons :|published| t))
                      :cookies (list (cons "session_id" session-id)))
          (direct-post "/api/posts"
                      :json (list (cons :|title| "Public Post 2")
                                 (cons :|content| "Content 2")
                                 (cons :|published| t))
                      :cookies (list (cons "session_id" session-id))))

        ;; 一覧取得（認証不要）
        (multiple-value-bind (body status headers)
            (direct-get "/api/posts")
          (declare (ignore headers))
          (assert-direct-status 200 status)
          (assert-direct-json body "data" "posts")
          (assert-direct-json body "data" "pagination"))))))

(deftest post-list-direct-pagination-test
  (testing "GET /api/posts?page=2&per_page=5 - ページネーション（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (body status headers)
            (direct-get "/api/posts" :query-string "page=2&per_page=5")
          (declare (ignore headers))
          (assert-direct-status 200 status)
          (let* ((parsed (jzon:parse body))
                 (pagination (gethash "pagination" (gethash "data" parsed))))
            (ok (= (gethash "page" pagination) 2) "page should be 2")
            (ok (= (gethash "per_page" pagination) 5) "per_page should be 5")))))))

;;;
;;; GET /api/posts/:id - 投稿詳細（直接呼び出し）
;;;

(deftest post-get-direct-published-test
  (testing "GET /api/posts/:id - 公開投稿取得（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          ;; 投稿作成
          (multiple-value-bind (create-body create-status create-headers)
              (direct-post "/api/posts"
                          :json (list (cons :|title| "Public Post")
                                     (cons :|content| "Content")
                                     (cons :|published| t))
                          :cookies (list (cons "session_id" session-id)))
            (declare (ignore create-status create-headers))
            ;; IDを抽出
            (let* ((parsed (jzon:parse create-body))
                   (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
              ;; 認証なしで取得可能
              (multiple-value-bind (body status headers)
                  (direct-get (format nil "/api/posts/~D" post-id))
                (declare (ignore headers))
                (assert-direct-status 200 status)
                (assert-direct-json body "data" "post" "title")))))))))

(deftest post-get-direct-draft-owner-test
  (testing "GET /api/posts/:id - 下書き投稿取得（所有者）（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          ;; 下書き投稿作成
          (multiple-value-bind (create-body create-status create-headers)
              (direct-post "/api/posts"
                          :json (list (cons :|title| "Draft Post")
                                     (cons :|content| "Content")
                                     (cons :|published| nil))
                          :cookies (list (cons "session_id" session-id)))
            (declare (ignore create-status create-headers))
            (let* ((parsed (jzon:parse create-body))
                   (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
              ;; 所有者として取得可能
              (multiple-value-bind (body status headers)
                  (direct-get (format nil "/api/posts/~D" post-id)
                             :cookies (list (cons "session_id" session-id)))
                (declare (ignore headers))
                (assert-direct-status 200 status)
                (assert-direct-json body "data" "post" "title")))))))))

(deftest post-get-direct-draft-non-owner-test
  (testing "GET /api/posts/:id - 下書き投稿取得（非所有者）→404（直接呼び出し）"
    (with-test-environment
      (with-test-db
        ;; ユーザー1が下書き作成
        (multiple-value-bind (session-id1 user1)
            (create-test-session)
          (declare (ignore user1))
          (multiple-value-bind (create-body create-status create-headers)
              (direct-post "/api/posts"
                          :json (list (cons :|title| "Draft Post")
                                     (cons :|content| "Content")
                                     (cons :|published| nil))
                          :cookies (list (cons "session_id" session-id1)))
            (declare (ignore create-status create-headers))
            (let* ((parsed (jzon:parse create-body))
                   (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
              ;; ユーザー2として取得試行
              (multiple-value-bind (session-id2 user2)
                  (create-test-session)
                (declare (ignore user2))
                (multiple-value-bind (body status headers)
                    (direct-get (format nil "/api/posts/~D" post-id)
                               :cookies (list (cons "session_id" session-id2)))
                  (declare (ignore body headers))
                  (assert-direct-status 404 status))))))))))

(deftest post-get-direct-invalid-id-test
  (testing "GET /api/posts/:id - 不正なID（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (body status headers)
            (direct-get "/api/posts/abc")
          (declare (ignore body headers))
          (assert-direct-status 400 status))))))

(deftest post-get-direct-not-found-test
  (testing "GET /api/posts/:id - 存在しないID→404（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (body status headers)
            (direct-get "/api/posts/999999")
          (declare (ignore body headers))
          (assert-direct-status 404 status))))))

;;;
;;; PUT /api/posts/:id - 投稿更新（直接呼び出し）
;;;

(deftest post-update-direct-success-test
  (testing "PUT /api/posts/:id - 投稿更新成功（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          ;; 投稿作成
          (multiple-value-bind (create-body create-status create-headers)
              (direct-post "/api/posts"
                          :json (list (cons :|title| "Original Title")
                                     (cons :|content| "Original Content"))
                          :cookies (list (cons "session_id" session-id)))
            (declare (ignore create-status create-headers))
            (let* ((parsed (jzon:parse create-body))
                   (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
              ;; 更新
              (multiple-value-bind (body status headers)
                  (direct-put (format nil "/api/posts/~D" post-id)
                             :json (list (cons :|title| "Updated Title"))
                             :cookies (list (cons "session_id" session-id)))
                (declare (ignore headers))
                (assert-direct-status 200 status)
                (assert-direct-json body "data" "post" "title")))))))))

(deftest post-update-direct-publish-test
  (testing "PUT /api/posts/:id - 下書きを公開に変更（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          ;; 下書き作成
          (multiple-value-bind (create-body create-status create-headers)
              (direct-post "/api/posts"
                          :json (list (cons :|title| "Draft")
                                     (cons :|content| "Content")
                                     (cons :|published| nil))
                          :cookies (list (cons "session_id" session-id)))
            (declare (ignore create-status create-headers))
            (let* ((parsed (jzon:parse create-body))
                   (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
              ;; 公開に変更
              (multiple-value-bind (body status headers)
                  (direct-put (format nil "/api/posts/~D" post-id)
                             :json (list (cons :|published| t))
                             :cookies (list (cons "session_id" session-id)))
                (declare (ignore headers))
                (assert-direct-status 200 status)
                (assert-direct-json body "data" "post")))))))))

(deftest post-update-direct-unauthorized-test
  (testing "PUT /api/posts/:id - 未認証エラー（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (body status headers)
            (direct-put "/api/posts/1"
                       :json (list (cons :|title| "Updated")))
          (declare (ignore body headers))
          (assert-direct-status 401 status))))))

(deftest post-update-direct-forbidden-test
  (testing "PUT /api/posts/:id - 他人の投稿更新→403（直接呼び出し）"
    (with-test-environment
      (with-test-db
        ;; ユーザー1が投稿作成
        (multiple-value-bind (session-id1 user1)
            (create-test-session)
          (declare (ignore user1))
          (multiple-value-bind (create-body create-status create-headers)
              (direct-post "/api/posts"
                          :json (list (cons :|title| "Original")
                                     (cons :|content| "Content"))
                          :cookies (list (cons "session_id" session-id1)))
            (declare (ignore create-status create-headers))
            (let* ((parsed (jzon:parse create-body))
                   (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
              ;; ユーザー2として更新試行
              (multiple-value-bind (session-id2 user2)
                  (create-test-session)
                (declare (ignore user2))
                (multiple-value-bind (body status headers)
                    (direct-put (format nil "/api/posts/~D" post-id)
                               :json (list (cons :|title| "Hacked"))
                               :cookies (list (cons "session_id" session-id2)))
                  (declare (ignore body headers))
                  (assert-direct-status 403 status))))))))))

(deftest post-update-direct-not-found-test
  (testing "PUT /api/posts/:id - 存在しない投稿の更新→404（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          (multiple-value-bind (body status headers)
              (direct-put "/api/posts/999999"
                         :json (list (cons :|title| "Updated"))
                         :cookies (list (cons "session_id" session-id)))
            (declare (ignore body headers))
            (assert-direct-status 404 status)))))))

;;;
;;; DELETE /api/posts/:id - 投稿削除（直接呼び出し）
;;;

(deftest post-delete-direct-success-test
  (testing "DELETE /api/posts/:id - 投稿削除成功（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          ;; 投稿作成
          (multiple-value-bind (create-body create-status create-headers)
              (direct-post "/api/posts"
                          :json (list (cons :|title| "ToDelete")
                                     (cons :|content| "Content"))
                          :cookies (list (cons "session_id" session-id)))
            (declare (ignore create-status create-headers))
            (let* ((parsed (jzon:parse create-body))
                   (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
              ;; 削除
              (multiple-value-bind (body status headers)
                  (direct-delete (format nil "/api/posts/~D" post-id)
                                :cookies (list (cons "session_id" session-id)))
                (declare (ignore headers))
                (assert-direct-status 200 status)
                (assert-direct-json body "data" "message"))
              ;; 削除後は取得不可
              (multiple-value-bind (body status headers)
                  (direct-get (format nil "/api/posts/~D" post-id)
                             :cookies (list (cons "session_id" session-id)))
                (declare (ignore body headers))
                (assert-direct-status 404 status)))))))))

(deftest post-delete-direct-unauthorized-test
  (testing "DELETE /api/posts/:id - 未認証エラー（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (body status headers)
            (direct-delete "/api/posts/1")
          (declare (ignore body headers))
          (assert-direct-status 401 status))))))

(deftest post-delete-direct-forbidden-test
  (testing "DELETE /api/posts/:id - 他人の投稿削除→403（直接呼び出し）"
    (with-test-environment
      (with-test-db
        ;; ユーザー1が投稿作成
        (multiple-value-bind (session-id1 user1)
            (create-test-session)
          (declare (ignore user1))
          (multiple-value-bind (create-body create-status create-headers)
              (direct-post "/api/posts"
                          :json (list (cons :|title| "Original")
                                     (cons :|content| "Content"))
                          :cookies (list (cons "session_id" session-id1)))
            (declare (ignore create-status create-headers))
            (let* ((parsed (jzon:parse create-body))
                   (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
              ;; ユーザー2として削除試行
              (multiple-value-bind (session-id2 user2)
                  (create-test-session)
                (declare (ignore user2))
                (multiple-value-bind (body status headers)
                    (direct-delete (format nil "/api/posts/~D" post-id)
                                  :cookies (list (cons "session_id" session-id2)))
                  (declare (ignore body headers))
                  (assert-direct-status 403 status))))))))))

(deftest post-delete-direct-not-found-test
  (testing "DELETE /api/posts/:id - 存在しない投稿の削除→404（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          (multiple-value-bind (body status headers)
              (direct-delete "/api/posts/999999"
                            :cookies (list (cons "session_id" session-id)))
            (declare (ignore body headers))
            (assert-direct-status 404 status)))))))

;;;
;;; GET /api/users/:user_id/posts - 特定ユーザーの公開投稿一覧（直接呼び出し）
;;;

(deftest user-posts-direct-test
  (testing "GET /api/users/:user_id/posts - 特定ユーザーの公開投稿一覧（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (let ((user-id (voro.model.user:user-id user)))
            ;; 投稿作成
            (direct-post "/api/posts"
                        :json (list (cons :|title| "Public")
                                   (cons :|content| "Content")
                                   (cons :|published| t))
                        :cookies (list (cons "session_id" session-id)))
            (direct-post "/api/posts"
                        :json (list (cons :|title| "Draft")
                                   (cons :|content| "Content")
                                   (cons :|published| nil))
                        :cookies (list (cons "session_id" session-id)))

            ;; 公開投稿のみ取得される
            (multiple-value-bind (body status headers)
                (direct-get (format nil "/api/users/~D/posts" user-id))
              (declare (ignore headers))
              (assert-direct-status 200 status)
              (assert-direct-json body "data" "posts")
              (assert-direct-json body "data" "pagination"))))))))

(deftest user-posts-direct-not-found-test
  (testing "GET /api/users/:user_id/posts - 存在しないユーザー→404（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (body status headers)
            (direct-get "/api/users/999999/posts")
          (declare (ignore body headers))
          (assert-direct-status 404 status))))))

(deftest user-posts-direct-invalid-id-test
  (testing "GET /api/users/:user_id/posts - 不正なuser_id→400（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (body status headers)
            (direct-get "/api/users/invalid/posts")
          (declare (ignore body headers))
          (assert-direct-status 400 status))))))

;;;
;;; GET /api/me/posts - 自分の投稿一覧（直接呼び出し）
;;;

(deftest my-posts-direct-test
  (testing "GET /api/me/posts - 自分の投稿一覧（全件）（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          ;; 投稿作成
          (direct-post "/api/posts"
                      :json (list (cons :|title| "My Public")
                                 (cons :|content| "Content")
                                 (cons :|published| t))
                      :cookies (list (cons "session_id" session-id)))
          (direct-post "/api/posts"
                      :json (list (cons :|title| "My Draft")
                                 (cons :|content| "Content")
                                 (cons :|published| nil))
                      :cookies (list (cons "session_id" session-id)))

          ;; 全件取得
          (multiple-value-bind (body status headers)
              (direct-get "/api/me/posts"
                         :cookies (list (cons "session_id" session-id)))
            (declare (ignore headers))
            (assert-direct-status 200 status)
            (assert-direct-json body "data" "posts")
            (assert-direct-json body "data" "pagination")))))))

(deftest my-posts-direct-filter-published-test
  (testing "GET /api/me/posts?published=true - 公開投稿のみ（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          ;; 投稿作成
          (direct-post "/api/posts"
                      :json (list (cons :|title| "Public Only")
                                 (cons :|content| "Content")
                                 (cons :|published| t))
                      :cookies (list (cons "session_id" session-id)))
          (direct-post "/api/posts"
                      :json (list (cons :|title| "Draft Only")
                                 (cons :|content| "Content")
                                 (cons :|published| nil))
                      :cookies (list (cons "session_id" session-id)))

          ;; 公開のみ取得
          (multiple-value-bind (body status headers)
              (direct-get "/api/me/posts"
                         :cookies (list (cons "session_id" session-id))
                         :query-string "published=true")
            (declare (ignore headers))
            (assert-direct-status 200 status)
            (assert-direct-json body "data" "posts")))))))

(deftest my-posts-direct-unauthorized-test
  (testing "GET /api/me/posts - 未認証エラー（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (body status headers)
            (direct-get "/api/me/posts")
          (declare (ignore body headers))
          (assert-direct-status 401 status))))))

;;;
;;; 境界値テスト（直接呼び出し）
;;;

(deftest post-create-direct-edge-cases-test
  (testing "POST /api/posts - 境界値タイトル（1文字）（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          (multiple-value-bind (body status headers)
              (direct-post "/api/posts"
                          :json (list (cons :|title| "A")
                                     (cons :|content| "Valid content"))
                          :cookies (list (cons "session_id" session-id)))
            (declare (ignore headers))
            (assert-direct-status 201 status)
            (let* ((parsed (jzon:parse body))
                   (post (gethash "post" (gethash "data" parsed))))
              (ok (string= (gethash "title" post) "A")
                  "Title should be 'A'")))))))

  (testing "POST /api/posts - タイトル超過（201文字）は400（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          (let ((title-201 (make-string 201 :initial-element #\T)))
            (multiple-value-bind (body status headers)
                (direct-post "/api/posts"
                            :json (list (cons :|title| title-201)
                                       (cons :|content| "Valid content"))
                            :cookies (list (cons "session_id" session-id)))
              (declare (ignore body headers))
              (assert-direct-status 400 status))))))))

;;;
;;; GET /api/me/posts/stats - 自分の投稿統計（直接呼び出し）
;;;

(deftest my-posts-stats-direct-success-test
  (testing "GET /api/me/posts/stats - 投稿統計取得成功（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (session-id user)
            (create-test-session)
          (declare (ignore user))
          ;; 投稿作成（公開1件、下書き1件）
          (direct-post "/api/posts"
                      :json (list (cons :|title| "Public Post")
                                 (cons :|content| "Content")
                                 (cons :|published| t))
                      :cookies (list (cons "session_id" session-id)))
          (direct-post "/api/posts"
                      :json (list (cons :|title| "Draft Post")
                                 (cons :|content| "Content")
                                 (cons :|published| nil))
                      :cookies (list (cons "session_id" session-id)))

          ;; 統計取得
          (multiple-value-bind (body status headers)
              (direct-get "/api/me/posts/stats"
                         :cookies (list (cons "session_id" session-id)))
            (declare (ignore headers))
            (assert-direct-status 200 status)
            (assert-direct-json body "data" "stats")))))))

(deftest my-posts-stats-direct-unauthorized-test
  (testing "GET /api/me/posts/stats - 未認証エラー（直接呼び出し）"
    (with-test-environment
      (with-test-db
        (multiple-value-bind (body status headers)
            (direct-get "/api/me/posts/stats")
          (declare (ignore body headers))
          (assert-direct-status 401 status))))))
