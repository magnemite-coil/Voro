(defpackage voro.util.validation
  (:use :cl)
  (:export
   :validate-password
   :validate-username
   :validate-email
   :validation-error
   :validation-error-message))

(in-package :voro.util.validation)

;;; カスタムエラー型

(define-condition validation-error (error)
  ((message :initarg :message
            :reader validation-error-message))
  (:documentation "バリデーションエラー")
  (:report (lambda (condition stream)
             (format stream "Validation error: ~A"
                     (validation-error-message condition)))))

;;; バリデーション関数

(defun validate-password (password)
  "パスワードのバリデーション

   要件:
   - 最低8文字
   - 少なくとも1つの英字を含む
   - 少なくとも1つの数字を含む

   戻り値: パスワードが有効ならT
   エラー: バリデーションエラーの場合は validation-error をシグナル"

  (cond
    ;; 長さチェック
    ((< (length password) 8)
     (error 'validation-error
            :message "Password must be at least 8 characters"))

    ;; 英字チェック
    ((not (find-if #'alpha-char-p password))
     (error 'validation-error
            :message "Password must contain at least one letter"))

    ;; 数字チェック
    ((not (find-if #'digit-char-p password))
     (error 'validation-error
            :message "Password must contain at least one number"))

    ;; すべてのチェックをパス
    (t t)))

(defun validate-username (username)
  "ユーザー名のバリデーション

   要件:
   - 3文字以上50文字以下
   - 英数字とアンダースコアのみ（正規表現: ^[a-zA-Z0-9_]+$）
   - 英字で始まる

   戻り値: ユーザー名が有効ならT
   エラー: バリデーションエラーの場合は validation-error をシグナル"

  (cond
    ;; 長さチェック
    ((< (length username) 3)
     (error 'validation-error
            :message "Username must be at least 3 characters"))

    ((> (length username) 50)
     (error 'validation-error
            :message "Username must not exceed 50 characters"))

    ;; 先頭文字チェック（英字で始まる）
    ((not (alpha-char-p (char username 0)))
     (error 'validation-error
            :message "Username must start with a letter"))

    ;; 使用可能文字チェック（英数字とアンダースコアのみ）
    ((not (every (lambda (c)
                   (or (alphanumericp c)
                       (char= c #\_)))
                 username))
     (error 'validation-error
            :message "Username must contain only letters, numbers, and underscores"))

    ;; すべてのチェックをパス
    (t t)))

(defun validate-email (email)
  "メールアドレスのバリデーション（実用的なチェック）

   要件:
   - user@domain.tld 形式
   - ローカル部: 英数字、ドット、ハイフン、アンダースコア、+、%
   - ドメイン部: 英数字、ドット、ハイフン
   - TLD: 最低2文字の英字
   - 長さ制限: 最大254文字（RFC 5321）
   - メールアドレスは必須項目

   戻り値: メールアドレスが有効ならT
   エラー: バリデーションエラーの場合は validation-error をシグナル"

  ;; NILチェック
  (unless email
    (error 'validation-error
           :message "Email address is required"))

  ;; 長さチェック
  (unless (<= (length email) 254)
    (error 'validation-error
           :message "Email address is too long (max 254 characters)"))

  ;; @ の個数チェック（分割前に実行）
  (let ((at-count (count #\@ email)))
    (unless (= at-count 1)
      (error 'validation-error
             :message "Email address must contain exactly one @ symbol")))

  ;; ローカル部とドメイン部に分割
  (let* ((at-pos (position #\@ email))
         (local-part (subseq email 0 at-pos))
         (domain-part (subseq email (1+ at-pos))))

    ;; ローカル部のバリデーション
    ;; - 先頭・末尾がドットでないこと
    ;; - 連続ドットがないこと
    ;; - 許可された文字のみ
    (unless (cl-ppcre:scan "^[a-zA-Z0-9._%+-]+$" local-part)
      (error 'validation-error
             :message "Invalid characters in email local part"))

    (when (or (char= (char local-part 0) #\.)
              (char= (char local-part (1- (length local-part))) #\.))
      (error 'validation-error
             :message "Email local part cannot start or end with a dot"))

    (when (cl-ppcre:scan "\\.\\." local-part)
      (error 'validation-error
             :message "Email local part cannot contain consecutive dots"))

    ;; ドメイン部のバリデーション
    (unless (cl-ppcre:scan "^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$" domain-part)
      (error 'validation-error
             :message "Invalid email domain format"))

    t))
