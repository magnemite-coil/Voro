(defsystem "voro"
  :version "0.1.0"
  :author "Your Name"
  :license "MIT"
  :depends-on (
    ;; Webフレームワーク
    :caveman2
    :clack
    :lack

    ;; HTTPサーバー
    :woo

    ;; ORM・DB
    :mito
    :sxql
    :dbi

    ;; Redis（独自セッション管理に使用）
    :cl-redis

    ;; JSON
    :jonathan

    ;; 暗号化
    :ironclad
    :flexi-streams

    ;; ユーティリティ
    :alexandria
    :split-sequence
    :local-time
    :cl-ppcre

    ;; 環境変数
    :uiop
  )
  :components (
    (:module "src"
     :components (
       ;; 設定
       (:file "config")

       ;; ユーティリティ
       (:module "util"
        :depends-on ("config")
        :components (
          (:file "log")
          (:file "response")
          (:file "crypto")
          (:file "validation")))

       ;; データベース
       (:file "db" :depends-on ("config" "util"))
       (:file "redis" :depends-on ("config" "util"))

       ;; モデル
       (:module "model"
        :depends-on ("db" "util")
        :components (
          (:file "user")))

       ;; ミドルウェア
       (:module "middleware"
        :depends-on ("redis" "util")
        :components (
          (:file "session")))

       ;; サービス
       (:module "service"
        :depends-on ("model" "middleware" "util")
        :components (
          (:file "auth")))

       ;; Webアプリケーション
       (:file "web")

       ;; ハンドラー
       (:module "handler"
        :depends-on ("service" "middleware" "util" "web")
        :components (
          (:file "auth")))

       ;; メインファイル
       (:file "main" :depends-on ("config" "db" "redis" "handler")))))
  :description "Voro - Common Lisp Blog System"
  :in-order-to ((test-op (test-op "voro/test"))))

(defsystem "voro/test"
  :depends-on ("voro" "rove")
  :components (
    (:module "test"
     :components (
       (:file "setup")
       (:file "util-test" :depends-on ("setup"))
       (:file "model-test" :depends-on ("setup"))
       (:file "service-test" :depends-on ("setup"))
       (:file "handler-test" :depends-on ("setup")))))
  :perform (test-op (o c) (symbol-call :rove :run c)))
