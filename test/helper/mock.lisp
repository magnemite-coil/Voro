;;; test/helper/mock.lisp
;;;
;;; モックユーティリティ - テスト用の関数モック機能を提供
;;;

(defpackage voro.test.helper.mock
  (:use :cl)
  (:export
   :with-mocked-function))

(in-package :voro.test.helper.mock)

(defmacro with-mocked-function ((fn-name lambda-expr) &body body)
  "関数を一時的にモックに置き換えて実行

   使用例:
   (with-mocked-function (voro.model.user:create-user
                          (lambda (&rest args)
                            (error \"Mocked error\")))
     (ok (signals (register-user ...) 'error)))

   注意:
   - パッケージがロックされている場合は sb-ext:unlock-package で解除が必要
   - 現時点では voro.* パッケージはロックされていないため不要
   - gensymを使用してネスト時の変数名衝突を防止"
  (let ((original-fn (gensym "ORIGINAL-FN-")))
    `(let ((,original-fn (symbol-function ',fn-name)))
       (unwind-protect
            (progn
              ;; パッケージロック対応（将来的にパッケージをロックした場合に備える）
              ;; 現時点では voro.* パッケージはロックされていないためコメントアウト
              ;; #+sbcl (sb-ext:unlock-package (symbol-package ',fn-name))
              (setf (symbol-function ',fn-name) ,lambda-expr)
              ,@body)
         (setf (symbol-function ',fn-name) ,original-fn)
         ;; #+sbcl (sb-ext:lock-package (symbol-package ',fn-name))
         ))))
