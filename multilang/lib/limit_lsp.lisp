(require :process)

(defpackage "LIMIT_LSP"
  (:nicknames "LIMIT")
  (:use "CL" "CL-USER"))

(in-package :limit)

(defparameter *semaphore* (mp:make-gate nil))

(defun initialize (n)
  (when (stringp n)
    (setq n (parse-integer n)))
  (format t "limit_lsp::initialize ~D~%" n)
  (setq *semaphore* (mp:make-gate nil))
  (loop repeat n
      do (mp:put-semaphore *semaphore*)))

(defun initially (self &rest vals)
  (mp:get-semaphore *semaphore*))

(defun finally (self &rest vals)
  (mp:put-semaphore *semaphore*))
