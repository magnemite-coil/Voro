;;;; scripts/run-coverage.lisp
;;;; SB-COVER を使用したテストカバレッジ測定スクリプト
;;;;
;;;; 使用方法:
;;;;   sbcl --non-interactive --load scripts/run-coverage.lisp
;;;;
;;;; 出力:
;;;;   coverage-report/cover-index.html

(in-package :cl-user)

;;; ============================================================
;;; 1. 初期設定
;;; ============================================================

;; プロジェクトルートを取得
;; *load-pathname* は scripts/run-coverage.lisp を指すため、親ディレクトリを使用
(defparameter *project-root*
  (let ((script-dir (uiop:pathname-directory-pathname *load-pathname*)))
    (if script-dir
        (uiop:pathname-parent-directory-pathname script-dir)
        (uiop:getcwd))))

;; 出力ディレクトリの設定（プロジェクトルート直下）
(defparameter *coverage-output-dir*
  (merge-pathnames "coverage-report/" *project-root*))

;; ASDF レジストリの設定（Docker環境対応）
;; voro.asd はプロジェクトルート直下にあるため、*project-root* を追加
(push *project-root* asdf:*central-registry*)

;;; ============================================================
;;; 2. SB-COVER 初期化
;;; ============================================================

;; SB-COVER モジュールのロード
(require :sb-cover)

;; 計測ポリシーの有効化
;; 重要: この宣言は quickload より前に実行する必要がある
(declaim (optimize sb-cover:store-coverage-data))

;;; ============================================================
;;; 3. FASLキャッシュのクリア
;;; ============================================================

;; 既存のコンパイル済みファイルがあると計測されないため、
;; キャッシュをクリアして再コンパイルを強制する
(asdf:clear-system :voro)

;;; ============================================================
;;; 4. 計測対象システムのロード
;;; ============================================================

;; voro 本体をロード（計測コードが挿入される）
(ql:quickload :voro :silent t)

;;; ============================================================
;;; 5. 計測ポリシーの無効化（テストコード用）
;;; ============================================================

;; テストコード自体は計測対象外にする
(declaim (optimize (sb-cover:store-coverage-data 0)))

;;; ============================================================
;;; 6. テストシステムのロード
;;; ============================================================

;; voro/test をロード（計測なし）
(ql:quickload :voro/test :silent t)

;;; ============================================================
;;; 7. カバレッジ測定の実行
;;; ============================================================

;; 過去のカバレッジデータをリセット
(sb-cover:reset-coverage)

;; テスト実行
(format t "~%========================================~%")
(format t "Running tests with coverage measurement~%")
(format t "========================================~%~%")

;; テスト成功フラグ（エラーがなければ成功とみなす）
(defparameter *test-passed* t)

(handler-case
    (progn
      (asdf:test-system :voro/test)
      (format t "~%Test completed successfully.~%"))
  (error (e)
    (format t "~%Test failed with error: ~A~%" e)
    (setf *test-passed* nil)))

;;; ============================================================
;;; 8. レポート生成
;;; ============================================================

(format t "~%========================================~%")
(format t "Generating coverage report~%")
(format t "========================================~%~%")

;; 出力ディレクトリを作成
(ensure-directories-exist *coverage-output-dir*)

;; HTMLレポート生成
;; :form-mode :whole - 式全体をマーク（デフォルト）
;; :external-format :utf-8 - ソースファイルのエンコーディング
(sb-cover:report *coverage-output-dir*
                 :form-mode :whole
                 :external-format :utf-8)

(format t "Coverage report generated: ~A~%"
        (merge-pathnames "cover-index.html" *coverage-output-dir*))

;;; ============================================================
;;; 9. 終了処理
;;; ============================================================

;; テスト結果に応じた終了コードで終了
(if *test-passed*
    (progn
      (format t "~%All tests passed. Exiting with code 0.~%")
      (sb-ext:exit :code 0))
    (progn
      (format t "~%Some tests failed. Exiting with code 1.~%")
      (sb-ext:exit :code 1)))
