(defpackage voro.test.web
  (:use :cl :rove)
  (:import-from :voro.web
                :*app*))

(in-package :voro.test.web)

;;;
;;; *app* インスタンステスト
;;;

(deftest test-app-instance
  (testing "*app* が存在する"
    (ok (not (null *app*))
        "*app* should be defined and not NIL"))

  (testing "*app* が <web> クラスのインスタンスである"
    ;; <web> クラスは voro.web パッケージ内部で定義
    (let ((web-class (find-class (find-symbol "<WEB>" :voro.web))))
      (ok (typep *app* web-class)
          "*app* should be an instance of <web> class")))

  (testing "*app* が関数として呼び出し可能（Lackアプリケーション）"
    ;; Lackアプリケーションは funcall 可能
    (ok (functionp (lack.component:to-app *app*))
        "*app* should be convertible to a Lack application")))

;;;
;;; クラス継承テスト
;;;

(deftest test-web-class-hierarchy
  (testing "<web> クラスが定義されている"
    (let ((web-class (find-class (find-symbol "<WEB>" :voro.web) nil)))
      (ok (not (null web-class))
          "<web> class should be defined")))

  (testing "<web> が <app> を継承している"
    ;; subtypep を使用してクラス継承を検証（closer-mop 不要）
    (let ((web-class (find-symbol "<WEB>" :voro.web))
          (app-class (find-symbol "<APP>" :caveman2)))
      (ok (subtypep web-class app-class)
          "<web> should inherit from <app>"))))
