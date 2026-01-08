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
     └── vite/      - Vite 開発サーバーキャッシュ

   注: カバレッジレポートは coverage-report/ に出力されます"
  ;; *load-truename* からスクリプト位置を取得し、親ディレクトリをプロジェクトルートとする
  ;; これにより CWD に依存せず、どこから実行しても正しく動作する
  (let* ((script-dir (uiop:pathname-directory-pathname *load-truename*))
         (project-root (uiop:pathname-parent-directory-pathname script-dir))
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
