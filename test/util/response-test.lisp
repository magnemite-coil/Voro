(defpackage voro.test.util.response
  (:use :cl :rove)
  (:import-from :voro.util.response
                :json-response
                :response-success
                :response-error)
  (:import-from :voro.util.json
                :parse-json))

(in-package :voro.test.util.response)

;;;
;;; ヘルパー関数
;;;

(defun parse-response-body (response)
  "レスポンスのボディ部分をパースして返す"
  (let ((body-list (third response)))
    (when body-list
      (parse-json (first body-list)))))

(defun get-response-status (response)
  "レスポンスのステータスコードを返す"
  (first response))

(defun get-response-headers (response)
  "レスポンスのヘッダーを返す"
  (second response))

(defun header-value (headers key)
  "ヘッダーから指定したキーの値を取得"
  (getf headers key))

;;;
;;; json-response テスト
;;;

(deftest test-json-response
  (testing "基本的なレスポンス生成"
    (let ((response (json-response 200 (list (cons :|message| "OK")))))
      (ok (= (get-response-status response) 200)
          "Status code is 200")
      (ok (string= (header-value (get-response-headers response) :content-type)
                   "application/json; charset=utf-8")
          "Content-Type is application/json")
      (let ((parsed (parse-response-body response)))
        (ok (string= (gethash "message" parsed) "OK")
            "Body contains message"))))

  (testing "追加ヘッダー付きレスポンス"
    (let ((response (json-response 201
                                    (list (cons :|id| 1))
                                    :additional-headers (list :x-custom "custom-value"))))
      (ok (= (get-response-status response) 201)
          "Status code is 201")
      (ok (string= (header-value (get-response-headers response) :x-custom)
                   "custom-value")
          "Custom header is present")))

  (testing "ネストしたalistのレスポンス"
    (let* ((nested-data (list (cons :|user|
                                    (list (cons :|id| 1)
                                          (cons :|name| "test")))))
           (response (json-response 200 nested-data))
           (parsed (parse-response-body response)))
      (let ((user (gethash "user" parsed)))
        (ok (= (gethash "id" user) 1)
            "Nested id is correct")
        (ok (string= (gethash "name" user) "test")
            "Nested name is correct"))))

  (testing "空のbodyのレスポンス"
    (let* ((response (json-response 204 nil))
           (parsed (parse-response-body response)))
      (ok (= (get-response-status response) 204)
          "Status code is 204")
      ;; nil は {} として出力される
      (ok (hash-table-p parsed)
          "Empty body is parsed as hash-table"))))

;;;
;;; response-success テスト
;;;

(deftest test-response-success
  (testing "基本的な成功レスポンス"
    (let* ((response (response-success (list (cons :|message| "OK"))))
           (parsed (parse-response-body response)))
      (ok (= (get-response-status response) 200)
          "Default status is 200")
      (ok (eq (gethash "success" parsed) t)
          "success is true")
      (let ((data (gethash "data" parsed)))
        (ok (string= (gethash "message" data) "OK")
            "data.message is OK"))))

  (testing "カスタムステータスコード"
    (let ((response (response-success (list (cons :|id| 1)) :status 201)))
      (ok (= (get-response-status response) 201)
          "Status code is 201")))

  (testing "追加ヘッダー付き成功レスポンス"
    (let ((response (response-success
                     (list (cons :|message| "Created"))
                     :status 201
                     :headers (list :set-cookie "session_id=abc123; HttpOnly"))))
      (ok (string= (header-value (get-response-headers response) :set-cookie)
                   "session_id=abc123; HttpOnly")
          "Set-Cookie header is present")))

  (testing "ネストしたデータ"
    (let* ((user-data (list (cons :|id| 1) (cons :|name| "testuser")))
           (response (response-success (list (cons :|user| user-data))))
           (parsed (parse-response-body response))
           (data (gethash "data" parsed))
           (user (gethash "user" data)))
      (ok (= (gethash "id" user) 1)
          "data.user.id is 1")
      (ok (string= (gethash "name" user) "testuser")
          "data.user.name is testuser")))

  (testing "配列データ"
    (let* ((items (list (list (cons :|id| 1)) (list (cons :|id| 2))))
           (response (response-success (list (cons :|items| items))))
           (parsed (parse-response-body response))
           (data (gethash "data" parsed))
           (result-items (gethash "items" data)))
      (ok (= (length result-items) 2)
          "items array has 2 elements")))

  (testing "nilデータは空オブジェクトとして出力される"
    (let* ((response (response-success nil))
           (parsed (parse-response-body response))
           (data (gethash "data" parsed)))
      (ok (hash-table-p data)
          "data should be a hash-table")
      (ok (zerop (hash-table-count data))
          "data should be empty object"))))

;;;
;;; response-error テスト
;;;

(deftest test-response-error
  (testing "基本的なエラーレスポンス"
    (let* ((response (response-error 400 "Bad Request"))
           (parsed (parse-response-body response)))
      (ok (= (get-response-status response) 400)
          "Status code is 400")
      (ok (eq (gethash "success" parsed) nil)
          "success is false")
      (ok (string= (gethash "error" parsed) "Bad Request")
          "error message is correct")))

  (testing "error-id付きエラーレスポンス"
    (let* ((response (response-error 500 "Internal Error" :error-id "ERR-12345"))
           (parsed (parse-response-body response)))
      (ok (string= (gethash "error_id" parsed) "ERR-12345")
          "error_id is present")))

  (testing "error-idなしの場合はerror_idキーが存在しない"
    (let* ((response (response-error 404 "Not Found"))
           (parsed (parse-response-body response)))
      ;; gethash の第2戻り値でキーの存在を確認
      (multiple-value-bind (value exists-p)
          (gethash "error_id" parsed)
        (declare (ignore value))
        (ok (null exists-p)
            "error_id key should not exist"))))

  (testing "各種HTTPステータスコード"
    ;; 400 Bad Request
    (ok (= (get-response-status (response-error 400 "Bad Request")) 400)
        "400 Bad Request")
    ;; 401 Unauthorized
    (ok (= (get-response-status (response-error 401 "Unauthorized")) 401)
        "401 Unauthorized")
    ;; 403 Forbidden
    (ok (= (get-response-status (response-error 403 "Forbidden")) 403)
        "403 Forbidden")
    ;; 404 Not Found
    (ok (= (get-response-status (response-error 404 "Not Found")) 404)
        "404 Not Found")
    ;; 500 Internal Server Error
    (ok (= (get-response-status (response-error 500 "Internal Server Error")) 500)
        "500 Internal Server Error"))

  (testing "追加ヘッダー付きエラーレスポンス"
    (let ((response (response-error 401 "Unauthorized"
                                     :headers (list :www-authenticate "Bearer"))))
      (ok (string= (header-value (get-response-headers response) :www-authenticate)
                   "Bearer")
          "WWW-Authenticate header is present"))))
