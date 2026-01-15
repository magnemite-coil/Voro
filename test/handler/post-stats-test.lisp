(defpackage voro.test.handler.post-stats
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment
                :with-test-db)
  (:import-from :voro.test.http-helper
                :with-test-server
                :http-get
                :assert-status
                :assert-500-error-response)
  (:import-from :voro.test.fixtures
                :create-test-user
                :create-test-session
                :create-test-post
                :create-test-post-with-date)
  (:import-from :voro.model.user
                :user-id)
  (:import-from :voro.model.post
                :create-post)
  (:import-from :local-time
                :now
                :timestamp-month
                :timestamp-year
                :encode-timestamp
                :timestamp-
                :+utc-zone+)
  ;; 500エラーテスト用
  (:import-from :voro.service.post
                :get-user-post-stats)
  (:local-nicknames (:jzon :com.inuoe.jzon)))

(in-package :voro.test.handler.post-stats)

;;; ヘルパー関数

(defun get-stats-from-body (body)
  "JSON文字列のbodyからstatsハッシュテーブルを取得"
  (let* ((parsed (jzon:parse body))
         (data (gethash "data" parsed))
         (stats (gethash "stats" data)))
    stats))

;;; GET /api/me/posts/stats - 投稿統計

(deftest test-get-post-stats-success
  (testing "認証済みユーザーで統計取得成功"
    (with-test-environment
      (with-test-server
        (with-test-db
          (let* ((user (create-test-user))
                 (session-id (create-test-session user)))
            ;; テストデータ作成
            (create-post (user-id user) "Post 1" "Content for post 1" :published t)
            (create-post (user-id user) "Post 2" "Content for post 2" :published t)
            (create-post (user-id user) "Draft" "Content for draft" :published nil)

            (multiple-value-bind (body status)
                (http-get "/api/me/posts/stats"
                         :cookies (list (cons "session_id" session-id)))
              (assert-status 200 status)
              ;; レスポンス構造: { data: { stats: { total, published, draft, this_month } } }
              (let ((stats (get-stats-from-body body)))
                (ok (= (gethash "total" stats) 3))
                (ok (= (gethash "published" stats) 2))
                (ok (= (gethash "draft" stats) 1))))))))))

(deftest test-get-post-stats-unauthorized
  (testing "未認証で401エラー"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status)
              (http-get "/api/me/posts/stats")
            (declare (ignore body))
            (assert-status 401 status)))))))

(deftest test-get-post-stats-empty
  (testing "投稿がない場合は全て0を返す"
    (with-test-environment
      (with-test-server
        (with-test-db
          (let* ((user (create-test-user))
                 (session-id (create-test-session user)))
            (multiple-value-bind (body status)
                (http-get "/api/me/posts/stats"
                         :cookies (list (cons "session_id" session-id)))
              (assert-status 200 status)
              (let ((stats (get-stats-from-body body)))
                (ok (= (gethash "total" stats) 0))
                (ok (= (gethash "published" stats) 0))
                (ok (= (gethash "draft" stats) 0))
                (ok (= (gethash "this_month" stats) 0))))))))))

(deftest test-get-post-stats-this-month
  (testing "今月の投稿のみカウントされる"
    (with-test-environment
      (with-test-server
        (with-test-db
          (let* ((user (create-test-user))
                 (session-id (create-test-session user))
                 (current-time (now))
                 ;; 月初 00:00:00 UTC
                 (start-of-month (encode-timestamp
                                   0 0 0 0 1
                                   (timestamp-month current-time :timezone +utc-zone+)
                                   (timestamp-year current-time :timezone +utc-zone+)
                                   :timezone +utc-zone+))
                 ;; 先月の日付（月初から1秒前）
                 (last-month-date (timestamp- start-of-month 1 :sec)))

            ;; 今月の投稿を作成
            (create-post (user-id user) "今月の投稿1" "Content..." :published t)

            ;; 先月の投稿を作成（created_at を手動で設定）
            (create-test-post-with-date :user user
                                        :title "先月の投稿"
                                        :content "Content..."
                                        :published t
                                        :created-at last-month-date)

            (multiple-value-bind (body status)
                (http-get "/api/me/posts/stats"
                         :cookies (list (cons "session_id" session-id)))
              (assert-status 200 status)
              (let ((stats (get-stats-from-body body)))
                (ok (= (gethash "total" stats) 2))       ;; 全投稿数
                (ok (= (gethash "this_month" stats) 1))  ;; 今月の投稿のみ
                ))))))))

(deftest test-get-post-stats-month-boundary
  (testing "月初の境界テスト"
    (with-test-environment
      (with-test-server
        (with-test-db
          (let* ((user (create-test-user))
                 (session-id (create-test-session user))
                 (current-time (now))
                 ;; 月初 00:00:00.000 UTC（ちょうど月初）
                 (start-of-month (encode-timestamp
                                   0 0 0 0 1
                                   (timestamp-month current-time :timezone +utc-zone+)
                                   (timestamp-year current-time :timezone +utc-zone+)
                                   :timezone +utc-zone+)))

            ;; ちょうど月初の投稿（含まれるべき）
            (create-test-post-with-date :user user
                                        :title "月初の投稿"
                                        :content "Content..."
                                        :published t
                                        :created-at start-of-month)

            ;; 月初の1秒前の投稿（含まれないべき）
            (create-test-post-with-date :user user
                                        :title "月初1秒前"
                                        :content "Content..."
                                        :published t
                                        :created-at (timestamp- start-of-month 1 :sec))

            (multiple-value-bind (body status)
                (http-get "/api/me/posts/stats"
                         :cookies (list (cons "session_id" session-id)))
              (assert-status 200 status)
              (let ((stats (get-stats-from-body body)))
                (ok (= (gethash "total" stats) 2))
                (ok (= (gethash "this_month" stats) 1))  ;; 月初の投稿のみ
                ))))))))

;;; ==========================================================================
;;; 500エラーテスト
;;; ==========================================================================

;;; E-4: GET /api/me/posts/stats - 内部エラー
(deftest test-get-post-stats-internal-error
  (testing "GET /api/me/posts/stats - サービス層エラー時は500"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            ;; get-user-post-stats を一時的に上書きしてエラーを発生させる
            (let ((original-fn #'voro.service.post:get-user-post-stats))
              (setf (fdefinition 'voro.service.post:get-user-post-stats)
                    (lambda (&rest args)
                      (declare (ignore args))
                      (error "Simulated database error")))
              (unwind-protect
                  (multiple-value-bind (body status headers)
                      (http-get "/api/me/posts/stats"
                               :cookies (list (cons "session_id" session-id)))
                    (declare (ignore headers))
                    (assert-status 500 status)
                    (assert-500-error-response body))
                ;; 必ず元の関数を復元
                (setf (fdefinition 'voro.service.post:get-user-post-stats)
                      original-fn)))))))))
