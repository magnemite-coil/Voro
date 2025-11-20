(defpackage voro.test.model
  (:use :cl :rove)
  (:import-from :voro.test.setup
                :with-test-environment)
  (:import-from :voro.model.user
                :create-user
                :find-user-by-username
                :verify-user-password))

(in-package :voro.test.model)

(deftest test-user-model
  (with-test-environment
    (testing "ユーザー作成とクエリ"
      (let ((user (create-user "modeltest" "password123" :email "model@example.com")))
        (ok (not (null user)))
        (ok (string= (voro.model.user:user-username user) "modeltest"))
        (ok (string= (voro.model.user:user-email user) "model@example.com"))))

    (testing "ユーザー名で検索"
      (create-user "findtest" "password123")
      (let ((found (find-user-by-username "findtest")))
        (ok (not (null found)))
        (ok (string= (voro.model.user:user-username found) "findtest"))))

    (testing "パスワード検証"
      (let ((user (create-user "passtest" "password123")))
        (ok (verify-user-password user "password123"))
        (ok (not (verify-user-password user "wrongpassword")))))))
