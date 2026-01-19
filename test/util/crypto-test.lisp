(defpackage voro.test.util.crypto
  (:use :cl :rove))

(in-package :voro.test.util.crypto)

;;;
;;; PBKDF2パラメータ回帰テスト
;;; 内部シンボル（::）でアクセス（エクスポートされていないため）
;;;

(deftest test-crypto-parameters-defined
  "PBKDF2パラメータの定義・型・値を検証する回帰テスト"
  (testing "PBKDF2パラメータが定義されている"
    (ok (boundp 'voro.util.crypto::*pbkdf2-iterations*)
        "*pbkdf2-iterations* is bound")
    (ok (boundp 'voro.util.crypto::*pbkdf2-digest*)
        "*pbkdf2-digest* is bound"))

  (testing "PBKDF2パラメータの型が正しい"
    (ok (integerp voro.util.crypto::*pbkdf2-iterations*)
        "*pbkdf2-iterations* is an integer")
    (ok (keywordp voro.util.crypto::*pbkdf2-digest*)
        "*pbkdf2-digest* is a keyword"))

  (testing "PBKDF2パラメータの値が期待通り（回帰テスト）"
    (ok (= voro.util.crypto::*pbkdf2-iterations* 100000)
        "*pbkdf2-iterations* should be 100000 (dev environment)")
    (ok (eq voro.util.crypto::*pbkdf2-digest* :sha256)
        "*pbkdf2-digest* should be :sha256")))

(deftest test-crypto-security-settings
  "セキュリティ設定の下限チェック（開発・テスト環境向け）"
  (testing "イテレーション回数が実用的な下限を満たす"
    (ok (>= voro.util.crypto::*pbkdf2-iterations* 10000)
        "Iteration count should be at least 10,000 (practical minimum for dev/test)"))

  (testing "ハッシュアルゴリズムがセキュアである"
    (ok (member voro.util.crypto::*pbkdf2-digest* '(:sha256 :sha384 :sha512))
        "PBKDF2 digest should be SHA-256 or stronger")))
