;;;; start-server.lisp
;;;;
;;;; 開発用サーバー起動スクリプト
;;;;
;;;; 使い方:
;;;;   sbcl --load start-server.lisp
;;;;
;;;; このスクリプトは以下を行います:
;;;;   1. Quicklispをロード
;;;;   2. プロジェクトローカルのFASLキャッシュを設定
;;;;   3. Voroシステムをロード
;;;;   4. サーバーを起動

;; Quicklispをロード
(load "~/quicklisp/setup.lisp")

;; プロジェクトローカルのキャッシュを設定
(load "scripts/setup-cache.lisp")

;; Voroシステムをロード
(ql:quickload :voro)

;; Voroパッケージに切り替え
(in-package :voro)

;; サーバー起動
(format t "~%========================================~%")
(format t "Starting Voro server...~%")
(format t "========================================~%~%")

(voro:start :port 8080)

;; サーバーを実行し続ける
(format t "~%========================================~%")
(format t "Server running at http://localhost:8080~%")
(format t "Press Ctrl+C to stop the server~%")
(format t "========================================~%~%")

(handler-case
    (loop (sleep 1))
  (sb-sys:interactive-interrupt ()
    (format t "~%Shutting down...~%")
    (voro:stop)
    (sb-ext:exit)))
