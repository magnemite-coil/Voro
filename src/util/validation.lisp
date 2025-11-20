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
   - NILの場合はスキップ（オプショナル項目）

   戻り値: メールアドレスが有効（またはNIL）ならT
   エラー: バリデーションエラーの場合は validation-error をシグナル"

  (when email
    ;; 長さチェック
    (unless (<= (length email) 254)
      (error 'validation-error
             :message "Email address is too long (max 254 characters)"))

    ;; 基本的な形式チェック
    (unless (cl-ppcre:scan "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$" email)
      (error 'validation-error
             :message "Invalid email format"))

    ;; 追加チェック: 連続ドットの検出
    (when (cl-ppcre:scan "\\.\\." email)
      (error 'validation-error
             :message "Email address cannot contain consecutive dots"))

    ;; 追加チェック: 先頭・末尾のドット
    (when (or (char= (char email 0) #\.)
              (char= (char email (1- (length email))) #\.))
      (error 'validation-error
             :message "Email address cannot start or end with a dot"))

    ;; @ の個数チェック
    (let ((at-count (count #\@ email)))
      (unless (= at-count 1)
        (error 'validation-error
               :message "Email address must contain exactly one @ symbol")))

    t))
