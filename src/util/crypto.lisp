(defpackage voro.util.crypto
  (:use :cl)
  (:export
   :hash-password
   :verify-password))

(in-package :voro.util.crypto)

(defparameter *pbkdf2-iterations* 100000
  "PBKDF2のイテレーション回数
   注: OWASP 2023推奨値はSHA-256で600,000回以上
       開発環境のパフォーマンスを考慮して100,000回に設定
       本番環境では600,000回以上への変更を推奨")

(defparameter *pbkdf2-digest* :sha256
  "PBKDF2のハッシュアルゴリズム")

(defun hash-password (password)
  "パスワードをPBKDF2でハッシュ化
   戻り値: ハッシュ化されたパスワード（文字列）
   フォーマット: PBKDF2$SHA256:100000$<salt>$<hash>"
  (let ((password-octets (flexi-streams:string-to-octets
                          password
                          :external-format :utf-8)))
    (ironclad:pbkdf2-hash-password-to-combined-string
     password-octets
     :digest *pbkdf2-digest*
     :iterations *pbkdf2-iterations*)))
     ;; salt は ironclad が自動生成（16バイトのランダムソルト）

(defun verify-password (plain-password hashed-password)
  "平文パスワードとハッシュ化パスワードを比較
   戻り値: 一致すればT、不一致ならNIL"
  (handler-case
      (let ((password-octets (flexi-streams:string-to-octets
                              plain-password
                              :external-format :utf-8)))
        (ironclad:pbkdf2-check-password password-octets hashed-password))
    (error ()
      ;; ハッシュ形式が不正な場合はNIL
      nil)))
