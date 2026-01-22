;;; test/service/post-test.lisp
;;;
;;; service/post.lisp の未カバー領域テスト
;;; - get-user-post-stats 関数のテスト
;;; - エラー伝播テスト（モック使用）
;;; - 内部関数の直接テスト（オプション）
;;;
;;; 注: 基本的なCRUD・権限・境界値テストは test/service-test.lisp でカバー済み
;;;

(defpackage voro.test.service.post
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment)
  (:import-from :voro.test.fixtures
                :create-test-user
                :create-test-post
                :create-test-post-with-date)  ;; 日付指定投稿作成用
  (:import-from :voro.test.helper.mock
                :with-mocked-function)
  (:import-from :voro.model.user
                :user-id)
  ;; voro.model.post: モック対象の create-post は完全修飾で参照するためimport不要
  (:import-from :voro.util.validation
                :validation-error)  ;; 内部関数テストで使用
  (:import-from :voro.service.post
                :create-new-post
                :get-user-post-stats))
  ;; 注: local-time の関数・定数はすべて完全修飾（local-time:now 等）で使用
  ;;     → import不要、一貫性のためimportを省略

(in-package :voro.test.service.post)

;;;
;;; SP-01: create-new-post DBエラー伝播テスト
;;;

(deftest test-create-new-post-db-error
  (with-test-environment
    ;; create-post をモックするため実際のDB操作は発生しない
    ;; validate-title/validate-content はDB不要のため with-test-db 不要
    ;; パターン参考: test/service/auth-test.lisp:24-40
    (testing "DB接続エラー時は例外を再スロー"
      (with-mocked-function (voro.model.post:create-post
                              (lambda (&rest args)
                                (declare (ignore args))
                                (error "Database connection failed")))
        (ok (signals (create-new-post 1 "Title" "Content") 'error)
            "DB error should propagate")))))

;;;
;;; SP-02: get-user-post-stats テスト
;;;

(deftest test-get-user-post-stats
  ;; 注: 各 testing ブロックは独立したユーザーを作成するため、
  ;; 前のテストの影響を受けない（test/service-test.lisp と同じパターン）
  (with-test-environment
    (testing "投稿統計の取得"
      (let* ((user (create-test-user))
             (user-id (user-id user)))
        ;; 公開2件、下書き1件を作成（フィクスチャ使用）
        (create-test-post :user user :title "Published 1" :published t)
        (create-test-post :user user :title "Published 2" :published t)
        (create-test-post :user user :title "Draft" :published nil)

        (let ((stats (get-user-post-stats user-id)))
          (ok (= (cdr (assoc :|total| stats)) 3) "Total is 3")
          (ok (= (cdr (assoc :|published| stats)) 2) "Published is 2")
          (ok (= (cdr (assoc :|draft| stats)) 1) "Draft is 1")
          ;; this_month の検証は「this_month: 今月/先月を明示的に検証」テストを参照
          )))

    (testing "投稿がない場合はすべて0"
      (let* ((user (create-test-user))
             (stats (get-user-post-stats (user-id user))))
        (ok (= (cdr (assoc :|total| stats)) 0) "Total is 0")
        (ok (= (cdr (assoc :|published| stats)) 0) "Published is 0")
        (ok (= (cdr (assoc :|draft| stats)) 0) "Draft is 0")
        (ok (= (cdr (assoc :|this_month| stats)) 0) "This month is 0")))

    (testing "this_month: 今月/先月を明示的に検証"
      ;; フレークテスト回避: UTC基準で月初を計算し、境界を明示的に指定
      ;; 参考: test/handler/post-stats-test.lisp の test-get-post-stats-this-month
      (let* ((user (create-test-user))
             (user-id (user-id user))
             (current-time (local-time:now))
             ;; UTC基準で月初 00:00:00 を計算（count-user-posts-this-month と同じロジック）
             (start-of-month (local-time:encode-timestamp
                               0 0 0 0 1  ;; nsec sec min hour day
                               (local-time:timestamp-month current-time :timezone local-time:+utc-zone+)
                               (local-time:timestamp-year current-time :timezone local-time:+utc-zone+)
                               :timezone local-time:+utc-zone+))
             ;; 先月 = 月初の1秒前（確実に前月になる）
             (last-month-date (local-time:timestamp- start-of-month 1 :sec)))
        ;; 今月の投稿: 2件（現在時刻で作成）
        (create-test-post-with-date :user user :title "This month 1"
                                    :published t :created-at current-time)
        (create-test-post-with-date :user user :title "This month 2"
                                    :published t :created-at current-time)
        ;; 先月の投稿: 1件（月初の1秒前 = 確実に前月）
        (create-test-post-with-date :user user :title "Last month"
                                    :published t :created-at last-month-date)

        (let ((stats (get-user-post-stats user-id)))
          (ok (= (cdr (assoc :|total| stats)) 3) "Total is 3")
          (ok (= (cdr (assoc :|this_month| stats)) 2) "This month is 2"))))))

;;;
;;; SP-03: 内部関数テスト（オプション）
;;;

(deftest test-validate-title
  (testing "空白のみは拒否"
    (ok (signals (voro.service.post::validate-title "   ")
                 'validation-error)
        "Whitespace-only title is rejected"))

  (testing "nilは拒否"
    (ok (signals (voro.service.post::validate-title nil)
                 'validation-error)
        "nil title is rejected"))

  (testing "200文字は許可"
    (let ((title-200 (make-string 200 :initial-element #\a)))
      (ok (null (voro.service.post::validate-title title-200))
          "200 chars is valid")))

  (testing "201文字は拒否"
    (let ((title-201 (make-string 201 :initial-element #\a)))
      (ok (signals (voro.service.post::validate-title title-201)
                   'validation-error)
          "201 chars is rejected"))))

(deftest test-validate-content
  (testing "空白のみは拒否"
    (ok (signals (voro.service.post::validate-content "   ")
                 'validation-error)
        "Whitespace-only content is rejected"))

  (testing "nilは拒否"
    (ok (signals (voro.service.post::validate-content nil)
                 'validation-error)
        "nil content is rejected"))

  (testing "100000文字は許可"
    (let ((content-100000 (make-string 100000 :initial-element #\a)))
      (ok (null (voro.service.post::validate-content content-100000))
          "100000 chars is valid")))

  (testing "100001文字は拒否"
    (let ((content-100001 (make-string 100001 :initial-element #\a)))
      (ok (signals (voro.service.post::validate-content content-100001)
                   'validation-error)
          "100001 chars is rejected"))))

(deftest test-normalize-pagination
  (testing "page上限"
    (multiple-value-bind (page per-page)
        (voro.service.post::normalize-pagination 20000 50)
      (ok (= page 10000) "Page capped at 10000")
      (ok (= per-page 50) "Per-page unchanged")))

  (testing "per-page上限"
    (multiple-value-bind (page per-page)
        (voro.service.post::normalize-pagination 1 200)
      (ok (= page 1) "Page unchanged")
      (ok (= per-page 100) "Per-page capped at 100")))

  (testing "nil入力時のデフォルト値"
    (multiple-value-bind (page per-page)
        (voro.service.post::normalize-pagination nil nil)
      (ok (= page 1) "Page defaults to 1")
      (ok (= per-page 20) "Per-page defaults to 20")))

  (testing "負の値は1に正規化"
    (multiple-value-bind (page per-page)
        (voro.service.post::normalize-pagination -5 -10)
      (ok (= page 1) "Negative page becomes 1")
      (ok (= per-page 1) "Negative per-page becomes 1")))

  (testing "0は1に正規化"
    (multiple-value-bind (page per-page)
        (voro.service.post::normalize-pagination 0 0)
      (ok (= page 1) "Zero page becomes 1")
      (ok (= per-page 1) "Zero per-page becomes 1"))))
