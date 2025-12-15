(defpackage voro.test.model.user
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment
                :with-test-db)
  (:import-from :voro.test.fixtures
                :create-test-user
                :*default-test-password*)
  (:import-from :voro.model.user
                :user
                :user-id
                :user-username
                :user-email
                :user-created-at
                :user-updated-at
                :create-user
                :find-user-by-id
                :find-user-by-username
                :verify-user-password))

(in-package :voro.test.model.user)

;;;
;;; create-user テスト
;;;

(deftest test-create-user
  (with-test-environment
    (with-test-db
      (testing "ユーザー作成の基本動作"
        (let ((user (create-user "newuser" "password123" :email "new@example.com")))
          (ok (not (null user))
              "User is created")
          (ok (string= "newuser" (user-username user))
              "Username is set correctly")
          (ok (string= "new@example.com" (user-email user))
              "Email is set correctly")))

      (testing "メールアドレスなしでユーザー作成"
        (let ((user (create-user "noemail" "password123")))
          (ok (not (null user))
              "User is created without email")
          (ok (null (user-email user))
              "Email is nil"))))))

(deftest test-create-user-duplicate
  (with-test-environment
    (with-test-db
      (testing "重複ユーザー名でエラー"
        (create-user "duplicate" "password123")
        ;; DBI/Mitoはユニーク制約違反時に dbi:dbi-database-error を投げる
        ;; これにより、接続失敗などの無関係なエラーでテストが誤って通ることを防ぐ
        (ok (signals (create-user "duplicate" "different456") 'dbi:dbi-database-error)
            "Creating user with duplicate username signals a database error")))))

;;;
;;; find-user-by-id テスト
;;;

(deftest test-find-user-by-id
  (with-test-environment
    (with-test-db
      (testing "IDでユーザーを検索 - 存在する場合"
        (let* ((created-user (create-test-user :username "findbyid"))
               (found-user (find-user-by-id (user-id created-user))))
          (ok (not (null found-user))
              "User is found")
          (ok (string= "findbyid" (user-username found-user))
              "Found user has correct username")
          (ok (= (user-id created-user) (user-id found-user))
              "IDs match")))

      (testing "IDでユーザーを検索 - 存在しない場合"
        (let ((found (find-user-by-id 999999)))
          (ok (null found)
              "Returns NIL for nonexistent ID")))

      (testing "IDでユーザーを検索 - 無効なID（0、負数）"
        (let ((found-zero (find-user-by-id 0))
              (found-negative (find-user-by-id -1)))
          (ok (null found-zero)
              "Returns NIL for ID=0")
          (ok (null found-negative)
              "Returns NIL for negative ID"))))))

;;;
;;; find-user-by-username テスト
;;;

(deftest test-find-user-by-username
  (with-test-environment
    (with-test-db
      (testing "ユーザー名で検索 - 存在する場合"
        (create-test-user :username "findbyname")
        (let ((found (find-user-by-username "findbyname")))
          (ok (not (null found))
              "User is found")
          (ok (string= "findbyname" (user-username found))
              "Username matches")))

      (testing "ユーザー名で検索 - 存在しない場合"
        (let ((found (find-user-by-username "nonexistentuser")))
          (ok (null found)
              "Returns NIL for nonexistent username")))

      ;; 注意: このテストはPostgreSQLのデフォルトコレーション（大文字小文字区別）を前提としている
      ;; 設計方針: ユーザー名は大文字小文字を区別する（セキュリティ上の理由）
      ;; 将来CITEXTに変更する場合は、このテストも更新が必要
      (testing "ユーザー名で検索 - 大文字小文字を区別（設計方針）"
        (create-test-user :username "CaseSensitive")
        (ok (null (find-user-by-username "casesensitive"))
            "Lowercase version not found (case-sensitive by design)")
        (ok (not (null (find-user-by-username "CaseSensitive")))
            "Exact case is found")))))

;;;
;;; user-email テスト
;;;

(deftest test-user-email
  (with-test-environment
    (with-test-db
      (testing "メールアドレスあり"
        (let ((user (create-user "withemail" "password123"
                                  :email "test@example.com")))
          (ok (string= "test@example.com" (user-email user))
              "Email is stored correctly")))

      (testing "メールアドレスなし（NIL）"
        (let ((user (create-user "withoutemail" "password123")))
          (ok (null (user-email user))
              "Email is NIL when not provided"))))))

;;;
;;; verify-user-password テスト
;;;

(deftest test-verify-user-password
  (with-test-environment
    (with-test-db
      (testing "正しいパスワードで検証成功"
        (let ((user (create-user "passtest" "correct123")))
          (ok (verify-user-password user "correct123")
              "Correct password returns T")))

      (testing "間違ったパスワードで検証失敗"
        (let ((user (create-user "passtest2" "correct123")))
          (ok (not (verify-user-password user "wrong456"))
              "Wrong password returns NIL")))

      (testing "空文字パスワードで検証失敗"
        (let ((user (create-user "passtest3" "correct123")))
          (ok (not (verify-user-password user ""))
              "Empty password returns NIL"))))))

;;;
;;; タイムスタンプテスト
;;;

(deftest test-user-timestamps
  (with-test-environment
    (with-test-db
      (testing "created_at が自動生成される"
        (let ((user (create-test-user)))
          (ok (not (null (user-created-at user)))
              "created_at is set")
          (ok (typep (user-created-at user) 'local-time:timestamp)
              "created_at is a timestamp")))

      (testing "updated_at が自動生成される"
        (let ((user (create-test-user)))
          (ok (not (null (user-updated-at user)))
              "updated_at is set")
          (ok (typep (user-updated-at user) 'local-time:timestamp)
              "updated_at is a timestamp")))

      (testing "created_at と updated_at は作成時に同じ"
        (let ((user (create-test-user)))
          ;; 作成直後は同じか非常に近い時刻
          (ok (local-time:timestamp<=
               (user-created-at user)
               (user-updated-at user))
              "created_at <= updated_at"))))))

;;;
;;; user-id テスト
;;;

(deftest test-user-id
  (with-test-environment
    (with-test-db
      (testing "user-idは正の整数を返す"
        (let ((user (create-test-user)))
          (ok (integerp (user-id user))
              "user-id is an integer")
          (ok (> (user-id user) 0)
              "user-id is positive")))

      (testing "異なるユーザーは異なるIDを持つ"
        (let ((user1 (create-test-user :username "user1"))
              (user2 (create-test-user :username "user2")))
          (ok (/= (user-id user1) (user-id user2))
              "Different users have different IDs"))))))

;;;
;;; 追加: エッジケーステスト
;;;

(deftest test-create-user-empty-username
  (with-test-environment
    (with-test-db
      (testing "空文字ユーザー名はModel層で許可される（バリデーションはUtil/Service層で実施）"
        ;; 現状の仕様確認:
        ;;   - Model層: DBアクセスの抽象化に専念
        ;;   - 空文字バリデーション: Util層で実施予定
        ;;   - PostgreSQLスキーマ: NOT NULL制約のみ（空文字は許可）
        (let ((user (create-user "" "password123")))
          (ok (not (null user))
              "Empty username is allowed at Model layer")
          (ok (string= "" (user-username user))
              "Username is stored as empty string"))))))

(deftest test-create-user-special-characters
  (with-test-environment
    (with-test-db
      (testing "特殊文字を含むユーザー名（Model層では許可）"
        ;; バリデーションはutil層で行う
        ;; Model層は受け取った値をそのまま保存
        (let ((user (create-user "user_123" "password123")))
          (ok (not (null user))
              "Username with underscore is allowed at model layer")))

      (testing "日本語ユーザー名（Model層では許可）"
        ;; Model層は文字エンコーディングが正しければ保存可能
        (let ((user (create-user "テストユーザー" "password123")))
          (ok (not (null user))
              "Japanese username is stored at model layer"))))))

(deftest test-verify-user-password-nil-user
  (with-test-environment
    (with-test-db
      (testing "NILユーザーでパスワード検証 → エラー"
        ;; verify-user-password は user-password を呼び出すため
        ;; NILユーザーではエラーになる
        (ok (signals (verify-user-password nil "password") 'error)
            "NIL user signals an error")))))
