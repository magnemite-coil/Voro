(defpackage voro.test.util.log
  (:use :cl :rove)
  (:import-from :voro.util.log
                :generate-error-id
                :log-error
                :log-info
                :log-warn
                :log-debug))

(in-package :voro.test.util.log)

;;;
;;; ヘルパー関数
;;;

(defun read-file-content (filepath)
  "ファイル内容を文字列として読み取る"
  (with-open-file (stream filepath :direction :input
                                   :if-does-not-exist nil)
    (when stream
      (let ((content (make-string (file-length stream))))
        (read-sequence content stream)
        content))))

(defmacro with-temp-log-file (&body body)
  "一時ログファイルを使用してテストを実行
   bodyの最後の式がファイル内容を必要とする場合、READ-FILE-CONTENTを使用
   注意: 並列実行時の衝突を避けるため、タイムスタンプ+乱数でファイル名を生成
   注意: 標準出力への出力を抑制して、テスト実行時のノイズを防止"
  (let ((temp-file (gensym "TEMP-FILE"))
        (original-log-file (gensym "ORIGINAL-LOG-FILE"))
        (original-log-level (gensym "ORIGINAL-LOG-LEVEL"))
        (null-stream (gensym "NULL-STREAM")))
    `(let* ((,temp-file (format nil "/tmp/voro-test-log-~A-~A.log"
                                (get-universal-time)
                                (random 1000000)))
            (,original-log-file voro.config::*log-file*)
            (,original-log-level voro.config::*log-level*)
            ;; 標準出力を抑制するためのnullストリーム
            (,null-stream (make-broadcast-stream)))
       (setf voro.config::*log-file* ,temp-file)
       (setf voro.config::*log-level* :debug)  ; 全レベル出力
       (unwind-protect
            ;; 標準出力を一時的に抑制してbodyを実行
            (let ((*standard-output* ,null-stream))
              ,@body)
         ;; クリーンアップ
         (setf voro.config::*log-file* ,original-log-file)
         (setf voro.config::*log-level* ,original-log-level)
         (when (probe-file ,temp-file)
           (delete-file ,temp-file))))))

;;;
;;; generate-error-id テスト
;;;

(deftest test-generate-error-id
  (testing "エラーIDの形式検証（16文字の英数字）"
    (let ((error-id (generate-error-id)))
      (ok (stringp error-id)
          "error-id is a string")
      (ok (= 16 (length error-id))
          "error-id is 16 characters")
      (ok (every (lambda (c)
                   (or (alpha-char-p c)
                       (digit-char-p c)))
                 error-id)
          "error-id contains only alphanumeric characters")))

  (testing "エラーIDの一意性検証"
    (let ((id1 (generate-error-id))
          (id2 (generate-error-id))
          (id3 (generate-error-id)))
      (ok (string/= id1 id2)
          "First two IDs are different")
      (ok (string/= id2 id3)
          "Second and third IDs are different")
      (ok (string/= id1 id3)
          "First and third IDs are different"))))

;;;
;;; log-level-priority テスト（内部関数）
;;;

(deftest test-log-level-priority
  (testing "ログレベルの優先度が正しく設定されている"
    (let ((debug-priority (voro.util.log::log-level-priority :debug))
          (info-priority (voro.util.log::log-level-priority :info))
          (warn-priority (voro.util.log::log-level-priority :warn))
          (error-priority (voro.util.log::log-level-priority :error)))
      (ok (< debug-priority info-priority)
          ":debug < :info")
      (ok (< info-priority warn-priority)
          ":info < :warn")
      (ok (< warn-priority error-priority)
          ":warn < :error"))))

;;;
;;; should-log-p テスト（内部関数）
;;;

(deftest test-should-log-p
  (testing "ログレベルフィルタリング - :info設定時"
    (let ((voro.config::*log-level* :info))
      (ok (not (voro.util.log::should-log-p :debug))
          ":debug should NOT be logged when level is :info")
      (ok (voro.util.log::should-log-p :info)
          ":info should be logged when level is :info")
      (ok (voro.util.log::should-log-p :warn)
          ":warn should be logged when level is :info")
      (ok (voro.util.log::should-log-p :error)
          ":error should be logged when level is :info")))

  (testing "ログレベルフィルタリング - :error設定時"
    (let ((voro.config::*log-level* :error))
      (ok (not (voro.util.log::should-log-p :debug))
          ":debug should NOT be logged when level is :error")
      (ok (not (voro.util.log::should-log-p :info))
          ":info should NOT be logged when level is :error")
      (ok (not (voro.util.log::should-log-p :warn))
          ":warn should NOT be logged when level is :error")
      (ok (voro.util.log::should-log-p :error)
          ":error should be logged when level is :error")))

  (testing "ログレベルフィルタリング - :debug設定時（全出力）"
    (let ((voro.config::*log-level* :debug))
      (ok (voro.util.log::should-log-p :debug)
          ":debug should be logged when level is :debug")
      (ok (voro.util.log::should-log-p :info)
          ":info should be logged when level is :debug")
      (ok (voro.util.log::should-log-p :warn)
          ":warn should be logged when level is :debug")
      (ok (voro.util.log::should-log-p :error)
          ":error should be logged when level is :debug"))))

;;;
;;; format-log-message テスト（内部関数）
;;;

(deftest test-format-log-message
  (testing "基本的なログメッセージフォーマット"
    (let ((message (voro.util.log::format-log-message :info "Test message")))
      (ok (stringp message)
          "Returns a string")
      (ok (search "INFO" message)
          "Contains log level")
      (ok (search "Test message" message)
          "Contains message")))

  (testing "コンテキスト付きログメッセージ"
    (let ((message (voro.util.log::format-log-message
                    :info "Test message"
                    :context (list :|user_id| 123 :|action| "login"))))
      (ok (search "user_id" message)
          "Contains context key")
      (ok (search "123" message)
          "Contains context value")))

  (testing "エラー付きログメッセージ"
    (let ((message (voro.util.log::format-log-message
                    :error "Something failed"
                    :error "Connection refused")))
      (ok (search "ERROR:" message)
          "Contains ERROR: prefix")
      (ok (search "Connection refused" message)
          "Contains error message"))))

;;;
;;; log-error テスト
;;;

(deftest test-log-error
  (testing "log-errorはエラーIDを返す"
    (with-temp-log-file
      (let ((error-id (log-error "Test error message")))
        (ok (stringp error-id)
            "Returns a string")
        (ok (= 16 (length error-id))
            "Returns 16-character error ID"))))

  (testing "log-errorはログファイルに出力する"
    (with-temp-log-file
      (let ((error-id (log-error "File output test")))
        (let ((content (read-file-content voro.config::*log-file*)))
          (ok (and content (search "File output test" content))
              "Log file contains the message")
          (ok (and content (search error-id content))
              "Log file contains the error ID")))))

  (testing "log-errorはコンテキスト付きで出力できる"
    (with-temp-log-file
      (log-error "Context test" :context (list :|key| "value"))
      (let ((content (read-file-content voro.config::*log-file*)))
        (ok (and content (search "key" content))
            "Log file contains context key")))))

;;;
;;; log-info, log-warn, log-debug テスト
;;;

(deftest test-log-info
  (testing "log-infoはファイルに出力する"
    (with-temp-log-file
      (log-info "Info message test")
      (let ((content (read-file-content voro.config::*log-file*)))
        (ok (and content (search "INFO" content))
            "Log file contains INFO level")
        (ok (and content (search "Info message test" content))
            "Log file contains the message")))))

(deftest test-log-warn
  (testing "log-warnはファイルに出力する"
    (with-temp-log-file
      (log-warn "Warning message test")
      (let ((content (read-file-content voro.config::*log-file*)))
        (ok (and content (search "WARN" content))
            "Log file contains WARN level")
        (ok (and content (search "Warning message test" content))
            "Log file contains the message")))))

(deftest test-log-debug
  (testing "log-debugはファイルに出力する（:debug設定時）"
    (with-temp-log-file
      (log-debug "Debug message test")
      (let ((content (read-file-content voro.config::*log-file*)))
        (ok (and content (search "DEBUG" content))
            "Log file contains DEBUG level")
        (ok (and content (search "Debug message test" content))
            "Log file contains the message")))))

;;;
;;; ログレベルフィルタリング統合テスト
;;; フィルタが実際にファイル出力を抑制することを検証
;;;

(deftest test-log-level-filtering-integration
  (testing ":info設定時にlog-debugはファイルに出力されない"
    (let* ((temp-file (format nil "/tmp/voro-test-log-filter-~A.log"
                              (get-universal-time)))
           (voro.config::*log-file* temp-file)
           (voro.config::*log-level* :info))  ; :info以上のみ出力
      (unwind-protect
           (progn
             (log-debug "This debug message should NOT appear")
             (let ((content (read-file-content temp-file)))
               (ok (or (null content) (string= "" content))
                   "Log file is empty when :debug is filtered")))
        (when (probe-file temp-file)
          (delete-file temp-file)))))

  (testing ":info設定時にlog-infoは出力され、log-debugは出力されない"
    (let* ((temp-file (format nil "/tmp/voro-test-log-mixed-~A.log"
                              (get-universal-time)))
           (voro.config::*log-file* temp-file)
           (voro.config::*log-level* :info))
      (unwind-protect
           (progn
             (log-debug "Debug message should NOT appear")
             (log-info "Info message should appear")
             (let ((content (read-file-content temp-file)))
               (ok (and content (search "Info message should appear" content))
                   "Log file contains info message")
               (ok (not (search "Debug message should NOT appear" (or content "")))
                   "Log file does NOT contain debug message")))
        (when (probe-file temp-file)
          (delete-file temp-file)))))

  (testing ":error設定時にlog-warn, log-info, log-debugは出力されない"
    (let* ((temp-file (format nil "/tmp/voro-test-log-error-only-~A.log"
                              (get-universal-time)))
           (voro.config::*log-file* temp-file)
           (voro.config::*log-level* :error))
      (unwind-protect
           (progn
             (log-debug "Debug should NOT appear")
             (log-info "Info should NOT appear")
             (log-warn "Warn should NOT appear")
             (log-error "Error should appear")
             (let ((content (read-file-content temp-file)))
               (ok (and content (search "Error should appear" content))
                   "Log file contains error message")
               (ok (not (search "Debug should NOT appear" (or content "")))
                   "Log file does NOT contain debug message")
               (ok (not (search "Info should NOT appear" (or content "")))
                   "Log file does NOT contain info message")
               (ok (not (search "Warn should NOT appear" (or content "")))
                   "Log file does NOT contain warn message")))
        (when (probe-file temp-file)
          (delete-file temp-file))))))
