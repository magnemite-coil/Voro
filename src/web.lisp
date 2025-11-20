(defpackage voro.web
  (:use :cl :caveman2)
  (:export :<app>
           :*app*))

(in-package :voro.web)

(defapp <app>)

(defparameter *app* (make-instance '<app>))

;; ルートは各ハンドラーファイルで定義される
;; handler/auth.lisp で defroute を使用して定義
