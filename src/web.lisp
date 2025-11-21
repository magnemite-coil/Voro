(defpackage voro.web
  (:use :cl :caveman2)
  (:export :*app*))

(in-package :voro.web)

;; アプリケーションクラスの定義
(defclass <web> (<app>) ())

;; アプリケーションインスタンスの作成
(defvar *app* (make-instance '<web>))

;; ルーティングルールをクリア（既存のルールがあれば削除）
(clear-routing-rules *app*)

;; ルートは各ハンドラーファイルで定義される
;; handler/auth.lisp で defroute を使用して定義
