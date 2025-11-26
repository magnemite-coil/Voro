(defpackage voro.util.log
  (:use :cl)
  (:import-from :voro.config
                :*log-level*
                :*log-file*)
  (:import-from :voro.util.json
                :to-json-plist)
  (:export
   :log-debug
   :log-info
   :log-warn
   :log-error
   :generate-error-id))

(in-package :voro.util.log)

;;; ログレベルの優先度
(defparameter *log-levels*
  '((:debug . 0)
    (:info . 1)
    (:warn . 2)
    (:error . 3)))

(defun log-level-priority (level)
  "ログレベルの優先度を返す"
  (cdr (assoc level *log-levels*)))

(defun should-log-p (level)
  "指定されたログレベルを出力すべきか判定"
  (>= (log-level-priority level)
      (log-level-priority *log-level*)))

(defun format-log-message (level message &key context error)
  "ログメッセージをフォーマット"
  (let ((timestamp (local-time:format-timestring
                    nil (local-time:now)
                    :format local-time:+iso-8601-format+))
        (context-str (if context
                         (format nil " ~A" (to-json-plist context))
                         ""))
        (error-str (if error
                      (format nil " ERROR: ~A" error)
                      "")))
    (format nil "[~A] ~A: ~A~A~A~%"
            timestamp level message context-str error-str)))

(defun write-log (level message &key context error)
  "ログをファイルと標準出力に書き込み"
  (when (should-log-p level)
    (let ((log-msg (format-log-message level message :context context :error error)))
      ;; 標準出力
      (format t "~A" log-msg)
      ;; ファイル出力
      (ensure-directories-exist *log-file*)
      (with-open-file (stream *log-file*
                              :direction :output
                              :if-exists :append
                              :if-does-not-exist :create)
        (format stream "~A" log-msg)))))

(defun generate-error-id ()
  "エラーIDを生成（16文字の英数字）"
  (let ((chars "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"))
    (coerce (loop repeat 16
                  collect (char chars (random (length chars))))
            'string)))

(defun log-debug (message &key context)
  "DEBUGレベルのログ出力"
  (write-log :debug message :context context))

(defun log-info (message &key context)
  "INFOレベルのログ出力"
  (write-log :info message :context context))

(defun log-warn (message &key context)
  "WARNレベルのログ出力"
  (write-log :warn message :context context))

(defun log-error (message &key context error)
  "ERRORレベルのログ出力（エラーIDを生成して返す）"
  (let ((error-id (generate-error-id)))
    (write-log :error message
               :context (append (list :|error_id| error-id) context)
               :error error)
    error-id))
