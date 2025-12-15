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
;;; 4.5 環境チェック
;;; ============================================================
;;; 注: この関数定義はvoroシステムのロード後に配置する必要がある
;;;     (voro.db, voro.redis パッケージが利用可能になった後)

(defun check-test-prerequisites ()
  "テスト実行前の環境チェック

  注意: 環境変数の自動設定は行わない（安全性のため）。
  未設定の場合は警告を出してユーザーに設定を促す。"

  ;; 環境変数チェック（警告のみ、自動設定しない）
  (let ((app-env (uiop:getenv "APP_ENV"))
        (test-mode (uiop:getenv "TEST_MODE")))

    (unless (string= app-env "test")
      (format *error-output*
              "~%WARNING: APP_ENV is not 'test' (current: ~A)~%~
               Please set: export APP_ENV=test~%"
              (or app-env "unset")))

    (unless (string= test-mode "true")
      (format *error-output*
              "~%WARNING: TEST_MODE is not 'true'~%~
               Please set: export TEST_MODE=true~%")))

  ;; DB接続テスト
  (format t "~%Checking database connection...~%")
  (handler-case
      (progn
        (voro.db:connect-db)
        (voro.db:disconnect-db)
        (format t "  Database connection: OK~%")
        t)
    (error (e)
      (format *error-output*
              "~%ERROR: Database connection failed~%~
               Error: ~A~%~
               ~%To run tests with coverage:~%~
                 1. Docker (recommended): make test-coverage~%~
                 2. Local: createdb voro_test && redis-server~%~
                    export APP_ENV=test TEST_MODE=true~%~
                    make test-coverage-local~%"
              e)
      (sb-ext:exit :code 1)))

  ;; Redis接続テスト
  (format t "Checking Redis connection...~%")
  (handler-case
      (progn
        (voro.redis:connect-redis)
        (voro.redis:disconnect-redis)
        (format t "  Redis connection: OK~%")
        t)
    (error (e)
      (format *error-output*
              "~%WARNING: Redis connection failed: ~A~%~
               Some tests may be skipped.~%" e)))

  (format t "~%Environment check completed.~%~%"))

;; 環境チェックを実行
(check-test-prerequisites)

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
