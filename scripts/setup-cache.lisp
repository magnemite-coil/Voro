;;;; setup-cache.lisp
;;;;
;;;; プロジェクト専用のFASLキャッシュ設定
;;;; このファイルをロードすると、コンパイル済みファイル(.fasl)が
;;;; プロジェクトディレクトリ内の .cache/fasl/ に保存されます。
;;;;
;;;; 使い方:
;;;;   sbcl --load scripts/setup-cache.lisp --eval "(ql:quickload :voro)"
;;;;
;;;; キャッシュクリア:
;;;;   rm -rf .cache/  # または make clean-cache

(in-package :cl-user)

(defun setup-project-cache ()
  "プロジェクト内のキャッシュディレクトリを設定

   キャッシュ構成:
     .cache/
     ├── fasl/      - Common Lisp コンパイル済みファイル
     ├── vite/      - Vite 開発サーバーキャッシュ
     └── coverage/  - カバレッジレポート"
  (let* ((project-root (uiop:getcwd))
         (cache-dir (merge-pathnames ".cache/fasl/" project-root)))

    ;; キャッシュディレクトリが存在しない場合は作成
    (ensure-directories-exist cache-dir)

    ;; ASDFの出力先を設定
    (asdf:initialize-output-translations
     `(:output-translations
       ;; プロジェクト内のファイルは .cache/fasl/ に出力
       (,(namestring project-root)
        (,(namestring cache-dir) :implementation))
       ;; Quicklisp等の外部ライブラリはデフォルト位置
       :inherit-configuration))

    (format t "~%✅ FASL cache directory configured: ~A~%" cache-dir)
    (format t "   All compiled files will be stored in this directory.~%")
    (format t "   To clear all caches: rm -rf .cache/ or make clean-cache~%~%")))

;; 自動的に設定を適用
(setup-project-cache)
