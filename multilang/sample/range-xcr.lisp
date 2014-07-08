(xcrypt-init "injob_lisp" "limit_lsp" "core")
(load "lib/limit_lsp.lisp")             ; fixme

(xcrypt-call "limit_lsp::initialize" 3)

(setq jobs
  (prepare-submit
   `((:id . "jobrng")
     ("RANGE0" . (30 40))
     ("RANGE1" . ,(loop for x from 0 upto 4 collect x))
     (:exe0 . "./sample/bin/fib")
     (:arg0_0@ . ,#'(lambda (jo &rest vals) (+ (parse-integer (nth 0 vals))
                                               (parse-integer (nth 1 vals)))))
     (:arg0_1@ . ,#'(lambda (jo &rest vals) (format nil "> out_~A" (jobobj-get jo "id"))))
     (:after . ,#'(lambda (jo &rest vals) (format t "Job ~A finished.~%" (jobobj-get jo "id"))))
     (:after_in_job . (lambda (jo) (format t "Job ~A finished.~%" (jobobj-get jo "id"))))
     )))
(sync jobs)

;; 上のsyncをコメントアウトすれば，実行後，対話環境でジョブの状態を確認できる
;; (mapcar #'get-job-status jobs)

#+comment
(mapcar #'prepare-submit-sync
        (mapcar #'(lambda (vals)
                    (let ((id (format nil "jobrng~A_~A"
                                      (nth 0 vals) (nth 1 vals))))
                      `((:id . ,id)
                        (:exe0 . "./bin/fib")
                        (:arg0_0 . ,(+ (nth 0 vals) (nth 1 vals)))
                        (:arg0_1 . ,(format nil "> out_~A" id)))))
                (product '(30 40) (loop for x from 0 upto 4 collect x))))
