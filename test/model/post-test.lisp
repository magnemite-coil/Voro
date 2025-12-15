(defpackage voro.test.model.post
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment
                :with-test-db)
  (:import-from :voro.test.fixtures
                :create-test-user
                :create-test-post
                :create-test-posts)
  ;; local-time は voro システムの間接依存として利用可能
  ;; （voro.asd: voro → :local-time）
  (:import-from :local-time
                :timestamp>=)
  (:import-from :voro.model.user
                :user-id)
  (:import-from :voro.model.post
                :post
                :post-id
                :post-user-id
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

(in-package :voro.test.model.post)

;;;
;;; create-post テスト
;;;

(deftest test-create-post
  (with-test-environment
    (with-test-db
      (testing "投稿作成の基本動作"
        (let* ((user (create-test-user))
               (user-id (user-id user))
               (post (create-post user-id "Test Title" "Test Content")))
          (ok (not (null post))
              "Post is created")
          (ok (= (post-user-id post) user-id)
              "user_id is set correctly")
          (ok (string= (post-title post) "Test Title")
              "Title is set correctly")
          (ok (string= (post-content post) "Test Content")
              "Content is set correctly")
          (ok (null (post-published post))
              "Published defaults to nil"))))))

(deftest test-create-post-published
  (with-test-environment
    (with-test-db
      (testing "公開フラグ付き投稿の作成"
        (let* ((user (create-test-user))
               (post (create-post (user-id user) "Published Post" "Content" :published t)))
          (ok (eq (post-published post) t)
              "Published flag is set to T"))))))

;;;
;;; find-post-by-id テスト
;;;

(deftest test-find-post-by-id
  (with-test-environment
    (with-test-db
      (testing "IDで投稿を検索 - 存在する場合"
        (let* ((user (create-test-user))
               (created-post (create-post (user-id user) "Find Test" "Content"))
               (found (find-post-by-id (post-id created-post))))
          (ok (not (null found))
              "Post is found")
          (ok (string= (post-title found) "Find Test")
              "Found post has correct title")
          (ok (= (post-id created-post) (post-id found))
              "IDs match")))

      (testing "IDで投稿を検索 - 存在しない場合"
        (let ((found (find-post-by-id 999999)))
          (ok (null found)
              "Returns NIL for nonexistent ID")))

      (testing "IDで投稿を検索 - 無効なID（0、負数）"
        (let ((found-zero (find-post-by-id 0))
              (found-negative (find-post-by-id -1)))
          (ok (null found-zero)
              "Returns NIL for ID=0")
          (ok (null found-negative)
              "Returns NIL for negative ID"))))))

;;;
;;; find-posts-by-user-id テスト
;;;

(deftest test-find-posts-by-user-id-all
  (with-test-environment
    (with-test-db
      (testing "ユーザーの全投稿取得（公開・非公開両方）"
        (let* ((user (create-test-user))
               (user-id (user-id user)))
          (create-post user-id "Post A" "Content" :published t)
          (create-post user-id "Post B" "Content" :published nil)
          (let ((posts (find-posts-by-user-id user-id :published :all)))
            (ok (= (length posts) 2)
                "Returns all posts regardless of published status")))))))

(deftest test-find-posts-by-user-id-published
  (with-test-environment
    (with-test-db
      (testing "ユーザーの公開投稿のみ取得"
        (let* ((user (create-test-user))
               (user-id (user-id user)))
          (create-post user-id "Public" "Content" :published t)
          (create-post user-id "Private" "Content" :published nil)
          (let ((posts (find-posts-by-user-id user-id :published t)))
            (ok (= (length posts) 1)
                "Returns only published posts")
            (ok (string= (post-title (first posts)) "Public")
                "The post is the published one")))))))

(deftest test-find-posts-by-user-id-draft
  (with-test-environment
    (with-test-db
      (testing "ユーザーの非公開投稿のみ取得"
        (let* ((user (create-test-user))
               (user-id (user-id user)))
          (create-post user-id "Public" "Content" :published t)
          (create-post user-id "Private" "Content" :published nil)
          (let ((posts (find-posts-by-user-id user-id :published nil)))
            (ok (= (length posts) 1)
                "Returns only draft posts")
            (ok (string= (post-title (first posts)) "Private")
                "The post is the draft one")))))))

(deftest test-find-posts-by-user-id-pagination
  (with-test-environment
    (with-test-db
      (testing "limit/offsetが正しく適用される"
        (let* ((user (create-test-user))
               (user-id (user-id user)))
          ;; 5件の投稿を作成
          (dotimes (i 5)
            (create-post user-id (format nil "Post ~D" i) "Content" :published t))
          ;; limit=2で取得
          (let ((limited-posts (find-posts-by-user-id user-id :published :all :limit 2)))
            (ok (= 2 (length limited-posts))
                "limit=2 returns exactly 2 posts"))
          ;; offset=2で取得（最初の2件をスキップ）
          (let ((offset-posts (find-posts-by-user-id user-id :published :all :limit 10 :offset 2)))
            (ok (= 3 (length offset-posts))
                "offset=2 skips first 2 posts, returns 3"))
          ;; limit + offset の組み合わせ
          (let ((paged-posts (find-posts-by-user-id user-id :published :all :limit 2 :offset 1)))
            (ok (= 2 (length paged-posts))
                "limit=2, offset=1 returns 2 posts")))))))

;;;
;;; find-published-posts テスト
;;;

(deftest test-find-published-posts
  (with-test-environment
    (with-test-db
      (testing "公開投稿が新着順（created_at DESC）で取得される"
        (let* ((user (create-test-user))
               (user-id (user-id user)))
          ;; 投稿を作成（created_atは挿入順に昇順）
          (let ((_post1 (create-post user-id "First Post" "Content" :published t))
                (_post2 (create-post user-id "Second Post" "Content" :published t))
                (_post3 (create-post user-id "Third Post" "Content" :published t)))
            (declare (ignore _post1 _post2 _post3))
            (let* ((posts (find-published-posts :limit 10))
                   ;; 取得結果のcreated_atリスト
                   (timestamps (mapcar #'post-created-at posts)))
              (ok (>= (length posts) 3)
                  "At least 3 posts returned")
              ;; 隣接する要素が降順（または等値）であることを検証
              (ok (every #'timestamp>=
                         timestamps
                         (cdr timestamps))
                  "Posts are ordered by created_at DESC (or equal)")))))

      (testing "公開投稿のみ取得される"
        (let* ((user (create-test-user))
               (user-id (user-id user)))
          (create-post user-id "Published" "Content" :published t)
          (create-post user-id "Draft" "Content" :published nil)
          (let ((posts (find-published-posts :limit 100)))
            (ok (every (lambda (p) (eq (post-published p) t)) posts)
                "All returned posts are published")))))))

(deftest test-find-published-posts-pagination
  (with-test-environment
    (with-test-db
      (testing "limit/offsetが正しく適用される"
        (let* ((user (create-test-user))
               (user-id (user-id user)))
          ;; 5件の公開投稿を作成
          (dotimes (i 5)
            (create-post user-id (format nil "Post ~D" i) "Content" :published t))
          ;; limit=2で取得
          (let ((limited-posts (find-published-posts :limit 2)))
            (ok (= 2 (length limited-posts))
                "limit=2 returns exactly 2 posts"))
          ;; offset=2で取得（最初の2件をスキップ）
          (let ((offset-posts (find-published-posts :limit 10 :offset 2)))
            (ok (= 3 (length offset-posts))
                "offset=2 skips first 2 posts, returns 3"))
          ;; limit + offset の組み合わせ
          (let ((paged-posts (find-published-posts :limit 2 :offset 1)))
            (ok (= 2 (length paged-posts))
                "limit=2, offset=1 returns 2 posts")))))))

;;;
;;; count-published-posts テスト
;;;

(deftest test-count-published-posts
  (with-test-environment
    (with-test-db
      (testing "公開投稿数のカウント"
        (let* ((user (create-test-user))
               (user-id (user-id user))
               (initial-count (count-published-posts)))
          (create-post user-id "Published 1" "Content" :published t)
          (create-post user-id "Draft" "Content" :published nil)
          (create-post user-id "Published 2" "Content" :published t)
          (ok (= (count-published-posts) (+ initial-count 2))
              "Only published posts are counted"))))))

;;;
;;; count-user-posts テスト
;;;

(deftest test-count-user-posts
  (with-test-environment
    (with-test-db
      (testing "ユーザー投稿数のカウント（各フィルター）"
        (let* ((user (create-test-user))
               (user-id (user-id user)))
          (create-post user-id "Post 1" "Content" :published t)
          (create-post user-id "Post 2" "Content" :published nil)
          (create-post user-id "Post 3" "Content" :published t)
          (ok (= (count-user-posts user-id :published :all) 3)
              "All posts counted")
          (ok (= (count-user-posts user-id :published t) 2)
              "Only published posts counted")
          (ok (= (count-user-posts user-id :published nil) 1)
              "Only draft posts counted"))))))

;;;
;;; post-to-alist テスト
;;;

(deftest test-post-to-alist
  (with-test-environment
    (with-test-db
      (testing "alist変換で全キーが含まれる"
        (let* ((user (create-test-user))
               (post (create-post (user-id user) "Alist Test" "Test Content" :published t))
               (alist (post-to-alist post)))
          (ok (assoc :|id| alist)
              "id key exists")
          (ok (assoc :|user_id| alist)
              "user_id key exists")
          (ok (assoc :|title| alist)
              "title key exists")
          (ok (assoc :|content| alist)
              "content key exists")
          (ok (assoc :|published| alist)
              "published key exists")
          (ok (assoc :|created_at| alist)
              "created_at key exists")
          (ok (assoc :|updated_at| alist)
              "updated_at key exists")
          (ok (string= (cdr (assoc :|title| alist)) "Alist Test")
              "title value is correct")
          (ok (string= (cdr (assoc :|content| alist)) "Test Content")
              "content value is correct")
          (ok (eq (cdr (assoc :|published| alist)) t)
              "published value is correct"))))))

(deftest test-post-to-alist-timestamp-format
  (with-test-environment
    (with-test-db
      (testing "created_at/updated_atがISO8601形式の文字列"
        (let* ((user (create-test-user))
               (post (create-post (user-id user) "Title" "Content"))
               (alist (post-to-alist post))
               (created-at (cdr (assoc :|created_at| alist)))
               (updated-at (cdr (assoc :|updated_at| alist))))
          ;; ISO8601形式: YYYY-MM-DDTHH:MM:SS.sss+HH:MM または類似形式
          ;; 最低限、文字列であり、T区切りが含まれることを検証
          (ok (stringp created-at)
              "created_at is a string")
          (ok (stringp updated-at)
              "updated_at is a string")
          (ok (search "T" created-at)
              "created_at contains ISO8601 T separator")
          (ok (search "T" updated-at)
              "updated_at contains ISO8601 T separator"))))))

;;;
;;; アクセサテスト
;;;

(deftest test-post-accessors
  (with-test-environment
    (with-test-db
      (testing "各アクセサ関数の動作"
        (let* ((user (create-test-user))
               (post (create-post (user-id user) "Accessor Test" "Content Body" :published t)))
          (ok (integerp (post-id post))
              "post-id returns integer")
          (ok (> (post-id post) 0)
              "post-id is positive")
          (ok (integerp (post-user-id post))
              "post-user-id returns integer")
          (ok (= (post-user-id post) (user-id user))
              "post-user-id matches user-id")
          (ok (stringp (post-title post))
              "post-title returns string")
          (ok (stringp (post-content post))
              "post-content returns string")
          (ok (eq (post-published post) t)
              "post-published returns T for published post"))))))

;;;
;;; タイムスタンプテスト
;;;

(deftest test-post-timestamps
  (with-test-environment
    (with-test-db
      (testing "created_atが自動生成される"
        (let ((post (create-test-post)))
          (ok (not (null (post-created-at post)))
              "created_at is set")
          (ok (typep (post-created-at post) 'local-time:timestamp)
              "created_at is a timestamp")))

      (testing "updated_atが自動生成される"
        (let ((post (create-test-post)))
          (ok (not (null (post-updated-at post)))
              "updated_at is set")
          (ok (typep (post-updated-at post) 'local-time:timestamp)
              "updated_at is a timestamp")))

      (testing "created_atとupdated_atは作成時に同じか近い"
        (let ((post (create-test-post)))
          ;; 作成直後は同じか非常に近い時刻
          (ok (local-time:timestamp<=
               (post-created-at post)
               (post-updated-at post))
              "created_at <= updated_at"))))))

;;;
;;; 境界値テスト
;;;

(deftest test-post-title-max-length
  (with-test-environment
    (with-test-db
      (testing "titleは200文字まで許容"
        (let* ((user (create-test-user))
               (max-title (make-string 200 :initial-element #\a))
               (post (create-post (user-id user) max-title "Content")))
          (ok (not (null post))
              "Post with 200 char title is created")
          (ok (= 200 (length (post-title post)))
              "Title length is 200")))

      (testing "titleが201文字以上でエラー"
        (let* ((user (create-test-user))
               (over-title (make-string 201 :initial-element #\a)))
          ;; PostgreSQL VARCHAR(200) 制約違反 → string_data_right_truncation
          ;; DBI経由で dbi:dbi-database-error として伝播
          (ok (signals (create-post (user-id user) over-title "Content") 'dbi:dbi-database-error)
              "Post with 201 char title signals database error"))))))

(deftest test-post-content-empty
  (with-test-environment
    (with-test-db
      (testing "contentは空文字列を許容"
        (let* ((user (create-test-user))
               (post (create-post (user-id user) "Title" "")))
          (ok (not (null post))
              "Post with empty content is created")
          (ok (string= "" (post-content post))
              "Content is empty string"))))))

;;;
;;; 追加: エッジケーステスト
;;;

(deftest test-create-post-nonexistent-user-id
  (with-test-environment
    (with-test-db
      (testing "存在しないuser_idで投稿作成 → エラー"
        ;; create-post は内部で find-user-by-id を呼び出し、
        ;; ユーザーが見つからない場合は error をシグナルする
        ;; （FK制約違反の前にアプリケーション層でチェック）
        ;; 注: (error ...) は simple-error 条件をシグナルする
        (ok (signals (create-post 999999 "Orphan Post" "Content")
                     'simple-error)
            "Nonexistent user_id raises error")))))

(deftest test-create-post-empty-title
  (with-test-environment
    (with-test-db
      (testing "空文字タイトルはModel層で許可（バリデーションはService/Handler層で実施予定）"
        ;; 注: Model層はDBアクセスの抽象化に専念し、バリデーションは上位層で実施
        ;; 将来的にService層で空タイトルを拒否するバリデーションを追加予定
        (let* ((user (create-test-user))
               (post (create-post (user-id user) "" "Content")))
          (ok (not (null post))
              "Empty title is allowed at Model layer")
          (ok (string= "" (post-title post))
              "Title is empty string"))))))

(deftest test-find-posts-by-nonexistent-user
  (with-test-environment
    (with-test-db
      (testing "存在しないuser_idで検索 → 空リスト（NIL）"
        (let ((posts (find-posts-by-user-id 999999)))
          (ok (null posts)
              "Returns NIL (empty list) for nonexistent user_id"))))))

(deftest test-count-user-posts-nonexistent-user
  (with-test-environment
    (with-test-db
      (testing "存在しないuser_idでカウント → 0"
        (ok (= 0 (count-user-posts 999999 :published :all))
            "Count is 0 for nonexistent user")
        (ok (= 0 (count-user-posts 999999 :published t))
            "Published count is 0 for nonexistent user")
        (ok (= 0 (count-user-posts 999999 :published nil))
            "Draft count is 0 for nonexistent user")))))

(deftest test-create-post-very-long-content
  (with-test-environment
    (with-test-db
      (testing "非常に長いcontent（TEXT型は制限なし）"
        (let* ((user (create-test-user))
               (long-content (make-string 100000 :initial-element #\a))
               (post (create-post (user-id user) "Title" long-content)))
          (ok (not (null post))
              "Post with very long content is created")
          (ok (= 100000 (length (post-content post)))
              "Content length is preserved"))))))

(deftest test-post-to-alist-published-false
  (with-test-environment
    (with-test-db
      (testing "非公開投稿のalist変換"
        (let* ((user (create-test-user))
               (post (create-post (user-id user) "Draft" "Content" :published nil))
               (alist (post-to-alist post)))
          ;; published が NIL の場合の挙動確認
          (ok (null (cdr (assoc :|published| alist)))
              "published is NIL/false in alist"))))))
