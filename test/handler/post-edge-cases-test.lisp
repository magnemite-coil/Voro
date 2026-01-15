(defpackage voro.test.handler.post-edge-cases
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
                :assert-json-response)
  (:import-from :voro.test.fixtures
                :create-test-user
                :create-test-session)
  ;; 500エラーテストでのモック対象関数
  (:import-from :voro.service.post
                :get-post
                :update-post
                :delete-post)
  (:local-nicknames (:jzon :com.inuoe.jzon)))

(in-package :voro.test.handler.post-edge-cases)

;;;
;;; handler/post.lisp エッジケーステスト
;;; 設計書: docs/design/handler-post-edge-case-tests.md
;;;
;;; 目標: カバレッジを 81.3% → 95%+ に向上
;;;

;;;
;;; 共通ヘルパー: 500エラーレスポンス検証
;;; 注: post-test.lisp にも同じ関数が存在。将来的に http-helper.lisp へ移動を推奨
;;;

(defun assert-500-error-response (body)
  "500エラーレスポンスの形式を検証する。
   期待形式: {\"success\": false, \"error\": \"string\", \"error_id\": \"...\"}
   - success が false であること
   - error が文字列であること
   - error_id がトップレベルに存在すること"
  (let* ((parsed (jzon:parse body))
         (success (gethash "success" parsed))
         (error-msg (gethash "error" parsed))
         (error-id (gethash "error_id" parsed)))
    (ok (not success) "success should be false")
    (ok (stringp error-msg) "error should be a string")
    (ok error-id "error_id should exist at top level")))

;;; ==========================================================================
;;; カテゴリA: JSON型変換エッジケース
;;; ==========================================================================

;;; A-1: コンテンツなしのリクエスト
(deftest post-create-missing-content-test
  (testing "POST /api/posts - コンテンツなしは400"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            (multiple-value-bind (body status headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Valid Title"))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore headers))
              (assert-status 400 status)
              ;; エラーメッセージの検証
              (let* ((parsed (jzon:parse body))
                     (error-msg (gethash "error" parsed)))
                (ok (stringp error-msg) "error message should exist")))))))))

;;; A-2: published=false の明示的指定
(deftest post-create-explicit-draft-test
  (testing "POST /api/posts - published=false で下書き作成"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            (multiple-value-bind (body status headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Draft Post")
                                     (cons :|content| "Draft Content")
                                     ;; Jzon: Lisp nil → JSON false にエンコードされる
                                     ;; http-helper.lisp の alist-to-hash-table 経由で jzon:stringify
                                     (cons :|published| nil))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore headers))
              (assert-status 201 status)
              (let* ((parsed (jzon:parse body))
                     (post (gethash "post" (gethash "data" parsed)))
                     (published (gethash "published" post)))
                (ok (null published) "published should be false")))))))))

;;; A-3: 厳密な型チェックの検証
(deftest post-create-published-strict-type-check-test
  (testing "POST /api/posts - published の厳密な型チェック動作"
    ;; ハンドラーコード: :published (eq published t)
    ;; (eq x t) は厳密な同一性チェックのため、t 以外は全て nil として扱われる
    ;;
    ;; | JSON入力 | Lisp値  | (eq x t) | 結果     |
    ;; |----------|---------|----------|----------|
    ;; | true     | t       | t        | 公開     |
    ;; | false    | nil     | nil      | 下書き   |
    ;; | 1        | 1       | nil      | 下書き   |
    ;; | "true"   | "true"  | nil      | 下書き   |
    ;;
    ;; これは意図した挙動（厳密な型チェック）
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            ;; published=1（数値）で投稿作成
            (multiple-value-bind (body status headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Test Title")
                                     (cons :|content| "Test Content")
                                     (cons :|published| 1))  ; 数値1
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore headers))
              (assert-status 201 status)
              ;; 数値1は (eq 1 t) = nil なので、下書きになる
              (let* ((parsed (jzon:parse body))
                     (post (gethash "post" (gethash "data" parsed)))
                     (published (gethash "published" post)))
                (ok (null published)
                    "published=1 should be treated as draft (strict type check)")))))))))

;;; ==========================================================================
;;; カテゴリB: 部分更新のバリエーション
;;; ==========================================================================

;;; B-1: コンテンツのみ更新
(deftest post-update-content-only-test
  (testing "PUT /api/posts/:id - コンテンツのみ更新"
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
              (let* ((parsed (jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; コンテンツのみ更新
                (multiple-value-bind (body status headers)
                    (http-put (format nil "/api/posts/~D" post-id)
                             :json (list (cons :|content| "Updated Content"))
                             :cookies (list (cons "session_id" session-id)))
                  (declare (ignore headers))
                  (assert-status 200 status)
                  (let* ((result (jzon:parse body))
                         (post (gethash "post" (gethash "data" result))))
                    (ok (string= (gethash "title" post) "Original Title")
                        "title should remain unchanged")
                    (ok (string= (gethash "content" post) "Updated Content")
                        "content should be updated")))))))))))

;;; B-2: 空のJSONボディで更新
(deftest post-update-empty-body-test
  (testing "PUT /api/posts/:id - 空のJSONボディ（変更なし）"
    ;; 空のJSONボディ {} を送信した場合:
    ;; - title, content: nil → when句でスキップ
    ;; - published-entry: nil → :not-specified → 変更なし
    ;; 期待: 200 OK、何も変更されない
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
                                     (cons :|content| "Original Content")
                                     (cons :|published| t))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore create-status create-headers))
              (let* ((parsed (jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; 空のJSONボディで更新
                (multiple-value-bind (body status headers)
                    (http-put (format nil "/api/posts/~D" post-id)
                             :json '()  ; 空のalist → {}
                             :cookies (list (cons "session_id" session-id)))
                  (declare (ignore headers))
                  (assert-status 200 status)
                  (let* ((result (jzon:parse body))
                         (post (gethash "post" (gethash "data" result))))
                    (ok (string= (gethash "title" post) "Original Title")
                        "title should remain unchanged")
                    (ok (string= (gethash "content" post) "Original Content")
                        "content should remain unchanged")
                    (ok (eq (gethash "published" post) t)
                        "published should remain true")))))))))))

;;; B-3: null値の明示的指定
(deftest post-update-null-title-test
  (testing "PUT /api/posts/:id - title=null の挙動"
    ;; JSONの {"title": null} を送信した場合:
    ;; - http-body（Yason）がJSON nullをLispのnilに変換
    ;; - get-body-param は nil を返す
    ;; - service層の update-post で (when title ...) によりスキップ
    ;; 期待: タイトルは変更されない
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
              (let* ((parsed (jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; title=null で更新
                (multiple-value-bind (body status headers)
                    (http-put (format nil "/api/posts/~D" post-id)
                             :json (list (cons :|title| nil)  ; JSON null
                                        (cons :|content| "Updated Content"))
                             :cookies (list (cons "session_id" session-id)))
                  (declare (ignore headers))
                  (assert-status 200 status)
                  (let* ((result (jzon:parse body))
                         (post (gethash "post" (gethash "data" result))))
                    (ok (string= (gethash "title" post) "Original Title")
                        "title should remain unchanged (null is ignored)")
                    (ok (string= (gethash "content" post) "Updated Content")
                        "content should be updated")))))))))))

;;; ==========================================================================
;;; カテゴリC: ページネーション追加ケース
;;; ==========================================================================

;;; C-1: per_page=0 の挙動
(deftest post-list-per-page-zero-test
  (testing "GET /api/posts?per_page=0 - 0は1に正規化される"
    ;; normalize-pagination の動作:
    ;; (max 1 (or per-page +per-page-default+))
    ;; = (max 1 (or 0 20))
    ;; = (max 1 0)  ; 0はnon-nilなのでorは0を返す
    ;; = 1
    ;;
    ;; 注意: デフォルト値20ではなく、最小値1に正規化される
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-get "/api/posts?per_page=0")
            (declare (ignore headers))
            (assert-status 200 status)
            (let* ((parsed (jzon:parse body))
                   (pagination (gethash "pagination" (gethash "data" parsed))))
              (ok (= (gethash "per_page" pagination) 1)
                  "per_page=0 should be normalized to 1 (not default 20)"))))))))

;;; C-2: 負の値のページネーション
(deftest post-list-negative-pagination-test
  (testing "GET /api/posts?page=-1&per_page=-5 - 負の値は1に正規化"
    ;; normalize-pagination の動作:
    ;; page: (max 1 -1) = 1
    ;; per_page: (max 1 -5) = 1
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-get "/api/posts?page=-1&per_page=-5")
            (declare (ignore headers))
            (assert-status 200 status)
            (let* ((parsed (jzon:parse body))
                   (pagination (gethash "pagination" (gethash "data" parsed))))
              (ok (= (gethash "page" pagination) 1)
                  "page=-1 should be normalized to 1")
              (ok (= (gethash "per_page" pagination) 1)
                  "per_page=-5 should be normalized to 1"))))))))

;;; C-3: 極端に大きな数値
(deftest post-list-extreme-page-test
  (testing "GET /api/posts?page=999999999 - 上限超えは+page-max+に正規化"
    ;; normalize-pagination の動作:
    ;; (min +page-max+ (max 1 999999999))
    ;; = (min 10000 999999999)
    ;; = 10000
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (body status headers)
              (http-get "/api/posts?page=999999999")
            (declare (ignore headers))
            (assert-status 200 status)
            (let* ((parsed (jzon:parse body))
                   (pagination (gethash "pagination" (gethash "data" parsed))))
              (ok (= (gethash "page" pagination) 10000)
                  "page=999999999 should be clamped to 10000"))))))))

;;; ==========================================================================
;;; カテゴリD: 特殊文字・エンコーディング
;;; ==========================================================================

;;; D-1: 日本語タイトル・コンテンツ
(deftest post-create-japanese-test
  (testing "POST /api/posts - 日本語タイトル・コンテンツ"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            (multiple-value-bind (body status headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "日本語タイトルテスト")
                                     (cons :|content| "日本語コンテンツです。"))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore headers))
              (assert-status 201 status)
              (let* ((parsed (jzon:parse body))
                     (post (gethash "post" (gethash "data" parsed))))
                (ok (string= (gethash "title" post) "日本語タイトルテスト")
                    "Japanese title should be stored correctly")
                (ok (string= (gethash "content" post) "日本語コンテンツです。")
                    "Japanese content should be stored correctly")))))))))

;;; D-2: 改行文字を含むタイトル
(deftest post-create-newline-in-title-test
  (testing "POST /api/posts - 改行を含むタイトルはそのまま保存される"
    ;; validate-title の動作:
    ;; (string-trim '(#\Space #\Tab #\Newline #\Return) title)
    ;; これは空白チェック時のみ使用され、実際の保存値はトリムされない
    ;;
    ;; 期待: 改行文字はそのまま保存される
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            (let ((title-with-newline (format nil "Line1~%Line2")))
              (multiple-value-bind (body status headers)
                  (http-post "/api/posts"
                            :json (list (cons :|title| title-with-newline)
                                       (cons :|content| "Content"))
                            :cookies (list (cons "session_id" session-id)))
                (declare (ignore headers))
                (assert-status 201 status)
                (let* ((parsed (jzon:parse body))
                       (post (gethash "post" (gethash "data" parsed)))
                       (saved-title (gethash "title" post)))
                  ;; 改行がそのまま保存されていることを確認
                  (ok (search (string #\Newline) saved-title)
                      "Newline should be preserved in title"))))))))))

;;; D-3: Unicode絵文字
(deftest post-create-emoji-test
  (testing "POST /api/posts - 絵文字を含むタイトル"
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            (multiple-value-bind (body status headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Hello 🎉 World 🌍")
                                     (cons :|content| "Emoji content 😀"))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore headers))
              (assert-status 201 status)
              (let* ((parsed (jzon:parse body))
                     (post (gethash "post" (gethash "data" parsed))))
                (ok (search "🎉" (gethash "title" post))
                    "Emoji should be preserved in title")
                (ok (search "😀" (gethash "content" post))
                    "Emoji should be preserved in content")))))))))

;;; D-4: 日本語200文字タイトル（境界値）
(deftest post-create-max-japanese-title-test
  (testing "POST /api/posts - 日本語200文字タイトル（境界値）"
    ;; PostgreSQLのVARCHAR(200)はバイト数ではなく文字数
    ;; Lispのlength関数も文字数を返す
    (with-test-environment
      (with-test-server
        (with-test-db
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            (let ((japanese-200 (make-string 200 :initial-element #\あ)))
              (multiple-value-bind (body status headers)
                  (http-post "/api/posts"
                            :json (list (cons :|title| japanese-200)
                                       (cons :|content| "Content"))
                            :cookies (list (cons "session_id" session-id)))
                (declare (ignore headers))
                (assert-status 201 status)
                (let* ((parsed (jzon:parse body))
                       (post (gethash "post" (gethash "data" parsed))))
                  (ok (= (length (gethash "title" post)) 200)
                      "200 Japanese characters should be accepted"))))))))))

;;; ==========================================================================
;;; カテゴリE: 500エラーテスト
;;; ==========================================================================

;;; E-1: GET /api/posts/:id - 内部エラー
(deftest post-get-internal-error-test
  (testing "GET /api/posts/:id - サービス層エラー時は500（IDチェック通過後）"
    (with-test-environment
      (with-test-server
        (with-test-db
          ;; テスト用投稿を作成
          (multiple-value-bind (session-id user)
              (create-test-session)
            (declare (ignore user))
            (multiple-value-bind (create-body create-status create-headers)
                (http-post "/api/posts"
                          :json (list (cons :|title| "Test Post")
                                     (cons :|content| "Test Content")
                                     (cons :|published| t))
                          :cookies (list (cons "session_id" session-id)))
              (declare (ignore create-status create-headers))
              (let* ((parsed (jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; get-post を一時的に上書きしてエラーを発生させる
                (let ((original-fn #'voro.service.post:get-post))
                  (setf (fdefinition 'voro.service.post:get-post)
                        (lambda (&rest args)
                          (declare (ignore args))
                          (error "Simulated database error")))
                  (unwind-protect
                      (multiple-value-bind (body status headers)
                          (http-get (format nil "/api/posts/~D" post-id))
                        (declare (ignore headers))
                        (assert-status 500 status)
                        (assert-500-error-response body))
                    ;; 必ず元の関数を復元
                    (setf (fdefinition 'voro.service.post:get-post) original-fn)))))))))))

;;; E-2: PUT /api/posts/:id - 内部エラー
(deftest post-update-internal-error-test
  (testing "PUT /api/posts/:id - サービス層エラー時は500（認証・バリデーション通過後）"
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
              (let* ((parsed (jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; update-post を一時的に上書きしてエラーを発生させる
                (let ((original-fn #'voro.service.post:update-post))
                  (setf (fdefinition 'voro.service.post:update-post)
                        (lambda (&rest args)
                          (declare (ignore args))
                          (error "Simulated database error")))
                  (unwind-protect
                      (multiple-value-bind (body status headers)
                          (http-put (format nil "/api/posts/~D" post-id)
                                   :json (list (cons :|title| "Updated Title"))
                                   :cookies (list (cons "session_id" session-id)))
                        (declare (ignore headers))
                        (assert-status 500 status)
                        (assert-500-error-response body))
                    ;; 必ず元の関数を復元
                    (setf (fdefinition 'voro.service.post:update-post) original-fn)))))))))))

;;; E-3: DELETE /api/posts/:id - 内部エラー
(deftest post-delete-internal-error-test
  (testing "DELETE /api/posts/:id - サービス層エラー時は500（認証・所有権チェック通過後）"
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
              (let* ((parsed (jzon:parse create-body))
                     (post-id (gethash "id" (gethash "post" (gethash "data" parsed)))))
                ;; delete-post を一時的に上書きしてエラーを発生させる
                (let ((original-fn #'voro.service.post:delete-post))
                  (setf (fdefinition 'voro.service.post:delete-post)
                        (lambda (&rest args)
                          (declare (ignore args))
                          (error "Simulated database error")))
                  (unwind-protect
                      (multiple-value-bind (body status headers)
                          (http-delete (format nil "/api/posts/~D" post-id)
                                      :cookies (list (cons "session_id" session-id)))
                        (declare (ignore headers))
                        (assert-status 500 status)
                        (assert-500-error-response body))
                    ;; 必ず元の関数を復元
                    (setf (fdefinition 'voro.service.post:delete-post) original-fn)))))))))))
