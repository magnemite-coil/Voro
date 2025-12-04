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
    :com.inuoe.jzon

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
          (:file "json")
          (:file "log")
          (:file "response")
          (:file "crypto")
          (:file "validation")
          (:file "request")))

       ;; データベース
       (:file "db" :depends-on ("config" "util"))
       (:file "redis" :depends-on ("config" "util"))

       ;; モデル
       (:module "model"
        :depends-on ("db" "util")
        :components (
          (:file "user")
          (:file "post")))

       ;; ミドルウェア
       (:module "middleware"
        :depends-on ("redis" "util")
        :components (
          (:file "session")))

       ;; サービス
       (:module "service"
        :depends-on ("model" "middleware" "util")
        :components (
          (:file "auth")
          (:file "post")))

       ;; Webアプリケーション
       (:file "web")

       ;; ハンドラー
       (:module "handler"
        :depends-on ("service" "middleware" "util" "web")
        :components (
          (:file "auth")
          (:file "post")))

       ;; メインファイル
       (:file "main" :depends-on ("config" "db" "redis" "handler")))))
  :description "Voro - Common Lisp Blog System"
  :in-order-to ((test-op (test-op "voro/test"))))

(defsystem "voro/test"
  :depends-on ("voro" "rove" "dexador")
  :components (
    (:module "test"
     :components (
       (:file "setup")
       (:file "fixtures" :depends-on ("setup"))
       (:file "http-helper" :depends-on ("setup"))
       (:file "util-test" :depends-on ("setup"))
       (:module "util"
        :depends-on ("setup")
        :components (
          (:file "response-test")))
       (:file "model-test" :depends-on ("setup" "fixtures"))
       (:file "service-test" :depends-on ("setup" "fixtures"))
       (:file "handler-test" :depends-on ("setup" "fixtures"))
       (:module "middleware"
        :depends-on ("setup" "fixtures")
        :components (
          (:file "session-test")))
       (:module "handler"
        :depends-on ("setup" "fixtures" "http-helper")
        :components (
          (:file "auth-test")
          (:file "post-test"))))))
  :perform (test-op (o c) (symbol-call :rove :run c)))
