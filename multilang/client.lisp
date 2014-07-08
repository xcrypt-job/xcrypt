;; -*- coding: utf-8 -*-
(require :socket)
(require :process)
(ql:quickload "cl-json")
(ql:quickload "anaphora")
(use-package :anaphora)

#+allegro
(setq *locale* (find-locale "utf-8-unix"))

(defvar *perl-host* "localhost")
(defvar *perl-port* 9001)		; eql to # in communicator.xcr
(defvar *perl-socket* nil)
(defvar *perl-socket-lock* nil)

(defvar *notification-table* (make-hash-table :test #'equal))
(defvar *function-table* (make-hash-table :test #'equal))


;; Script mode or Module mode?
(defvar *module-mode* nil)
(defvar *xcrypt-modules* (list))

(let ((args (or #+allegro (cdr (sys:command-line-arguments))
		#+clisp ext:*args*)))
  (let ((modules args))
    (when modules
      (setq *module-mode* t)
      (setq *xcrypt-modules* modules))))
  

;; Miscellaneous
(defun product (&rest lists)
  (if (endp lists)
      (list ())
    (let ((fst (car lists))
          (rem-comb (apply #'product (cdr lists))))
      (mapcan #'(lambda (fst-x)
                  (mapcar #'(lambda (comb) (cons fst-x comb)) rem-comb))
              fst))))

(defun alist-p (list)
  (cond
   ((null list) t)
   ((not (consp list)) nil)
   ((not (consp (car list))) nil)
   (t (alist-p (cdr list)))))

(defun assoc-euqal (item alist)
  (assoc item alist :test #'equal))

(defun string+ (&rest strings)
  (declare (list strings))
  (apply #'concatenate 'string
         (mapcar #'string strings)))

(defun strcat (string-list &optional (inter "") (prev "") (post ""))
  (declare (list string-list))
  (apply #'string+
         (separate-list string-list inter prev post)))

(defun add-paren (str &optional (open #\( open-p)
                                (close (if open-p open #\))))
  (string+ open str close))

(defun substitute-string (newstr oldch str)
  (declare (string newstr str) (character oldch))
  (with-output-to-string (ost)
    (map nil #'(lambda (ch)
                 (declare (character ch))
                 (if (char= ch oldch)
                     (write-string newstr ost)
                   (write-char ch ost)))
         str)))

(defun separate-list (elms separator
                      &optional (head nil head-p) (tail nil tail-p))
  (declare (list elms))
  (nconc (when head-p (list head))
         (when elms
           (cons (car elms)
                 (mapcan #'(lambda (x) (list separator x))
                         (cdr elms))))
         (when tail-p (list tail))))


#+(and allegro mswindows) (defparameter *sh-command* "\\cygwin\\bin\\sh.exe")
#+(or allegro kcl ecl cmu clisp)
(defun command-line (command &key args verbose other-options)
  (declare (string command) (list verbose) (list other-options))
  (let* ((quoted-cmd-args (mapcar #'(lambda (x) (add-paren
                                                (substitute-string "'\''" #\' x)
                                                #\'))
                                 (cons command args)))
         (cat-string
          #+(and allegro mswindows)
          (string+ *sh-command* " -c "
                   (strcat quoted-cmd-args #\Space #\" #\"))
          #-(and allegro mswindows)
          (strcat quoted-cmd-args #\Space)))
    (prin1 cat-string verbose)
    (fresh-line verbose)
    #+allegro
    (multiple-value-bind (sout eout rval)
                 (apply #'excl.osi:command-output cat-string :whole t
                        other-options)
               (when sout (format *error-output* "~&~A" sout))
               (when eout (format *error-output* "~&~A" eout))
               rval)
    #+kcl(apply #'system cat-string other-options)
    #+ecl(apply #'si::system cat-string other-options)
    #+(or cmu clisp)
    (apply #'ext:run-program command
           #+clisp :arguments args
           :wait t
           other-options)
    ))


;; Job object
(defstruct jobobj id)
(defun jobobj-get (jobj memb)
  (car (xcrypt-call "user::get" jobj memb)))
(defun jobobj-set (jobj memb val)
  (car (xcrypt-call "user::set" jobj memb val)))

;; notification-table
(defun ask-notification (thread-id
			 &optional (table *notification-table*))
  (let ((gate-retval (gethash thread-id table)))
    (cond
     ((null gate-retval)
      (setf (gethash thread-id table) (cons (mp:make-gate nil) nil)))
     ((mp:gate-open-p (car gate-retval))
      (mp:close-gate (car gate-retval)))
     (t
      (warn "Notification gate of ~S is unexpectedly closed." thread-id)))
    gate-retval))

(defun notify-with-retval (thread-id retval
			   &optional (table *notification-table*))
  (let ((gate-retval (gethash thread-id table)))
    (setf (cdr gate-retval) retval)
    (mp:open-gate (car gate-retval))))

(defun wait-notification (thread-id
			  &optional (table *notification-table*))
  (let ((gate-retval (gethash thread-id table)))
    (mp:process-wait "Waiting for the return value from the Perl process"
		     #'mp:gate-open-p (car gate-retval))
    (cdr gate-retval)))

(defun get-current-thread-id ()
  (mp:process-name mp:*current-process*))

;; convert before lisp->json
(defun convert-before-serialize (obj)
  (typecase obj
    (null obj)
    (list (cons (convert-before-serialize (car obj))
		(convert-before-serialize (cdr obj))))
    (function (convert-before-serialize-function obj))
    (jobobj (convert-before-serialize-jobobj obj))
    (t obj)))

(defun convert-before-serialize-function (fn)
  (let ((fnstr (write-to-string fn)))
    (setf (gethash fnstr *function-table*) fn)
    `(("type" . "function/ext")
      ("id" . ,fnstr))))

(defun convert-before-serialize-jobobj (jobj)
  `(("type" . "job_obj")
    ("id" . ,(jobobj-id jobj))
    ))

;; convert after json->lisp
(defun convert-after-deserialize (obj)
  (acond
   ((null obj) obj)
   ((remote-function obj)
    #'(lambda (&rest args) (apply #'xcrypt-call it args)))
   ((remote-job-object obj)
    (make-jobobj :id it))
   ((consp obj)
    (cons (convert-after-deserialize (car obj))
	  (convert-after-deserialize (cdr obj))))
   (t obj)))

(defun remote-function (obj)
  (and (alist-p obj)
       (equal (cdr (assoc :type obj)) "function/pl")
       (cdr (assoc :id obj))))

(defun remote-job-object (obj)
  (and (alist-p obj)
       (equal (cdr (assoc :type obj)) "job_obj")
       (cdr (assoc :id obj))))

;; Initialization
(defun generate-communicator-script (file-comm file-template libs)
  (with-open-file (s-comm file-comm :direction :output
		   :if-exists :supersede :if-does-not-exist :create)
    (format s-comm "use base qw(~{~A~^ ~});~%" libs)
    (with-open-file (s-temp file-template :direction :input)
      (do ((line (read-line s-temp nil nil) (read-line s-temp nil nil)))
	  ((null line) t)
	(write-string line s-comm)
	(write-char #\Newline s-comm)
	))))

;; Communication with Xcrypt
(defun dispatch (&aux (socket *perl-socket*))
  (loop
    (let* ((line (read-line socket))
	   (msg (json:decode-json-from-string line))
	   (kind (cdr (assoc :exec msg))))
      (format *error-output* "~&~A~%" line)
      (format *error-output* "~&~S~%" msg)
      (cond
       ((string= "return" kind)
	(let ((thread-id (cdr (assoc :thread--id msg)))
	      (retval (cdr (assoc :message msg))))
	  (assert (stringp thread-id))
	  (notify-with-retval thread-id (convert-after-deserialize retval))))
       ((string= "funcall" kind)
	(let ((func (cdr (assoc :function msg)))
	      (args (convert-after-deserialize (cdr (assoc :args msg))))
              (thread-id (cdr (assoc :thread--id msg))))
          (assert (stringp func))       ; !!! 遠隔関数の場合は関数objであるべき
          (assert (stringp thread-id))
	  (let ((proc
		 (acond
		  ((gethash func *function-table*)
		   #'(lambda () (apply it args)))
		  ((let* ((p-colon (search "::"func))) ; "package::fname"
                     (and p-colon
                          (let* ((package-name (string-upcase (subseq func 0 p-colon)))
                                 (fname        (string-upcase (subseq func (+ p-colon 2))))
                                 (package (find-package package-name)))
                            (and package
                                 (fboundp (intern fname package))
                                 (intern fname package)))))
		   (let ((fn (symbol-function it)))
		     #'(lambda () (apply fn args))))
		  (t
		   #'(lambda ()
		       (warn "No function associated with ~S" func)
		       nil)))))
	    (mp:process-run-function (format nil "Funcall of ~A (~A)" func (gensym))
	      #'(lambda (&aux (retval (convert-before-serialize (funcall proc))))
		  (xcrypt-send `(("thread_id" . ,thread-id)
				 ("exec" . "return")
				 ("message" . ,retval)
				 )))))))
       ((string= "finack" kind)
        (return nil))
       (t
	(error "Unknown message ~S" msg))))))

(defun xcrypt-send (obj &aux (socket *perl-socket*) (socket-lock *perl-socket-lock*))
  (let ((line (json:encode-json-to-string obj)))
    (mp:with-process-lock (socket-lock)
      (format socket "~A~%" line)
      (finish-output socket))
    line))

(defun make-connection-to-perl ()
  (let ((socket (socket:make-socket :format :text
				    :remote-host *perl-host*
				    :remote-port *perl-port*)))
    (if socket
	(progn
	  (setq *perl-socket* socket)
          (setq *perl-socket-lock* (mp:make-process-lock))
	  (mp:process-run-function "Dispatcher" #'dispatch))
      (progn
	(warn "Failed to connect to Xcrypt process")
	nil)))
  )

;;; user functions
(defun xcrypt-call (fn &rest args)
  (let ((thread-id (get-current-thread-id)))
    (ask-notification thread-id)
    (xcrypt-send `(("thread_id" . ,thread-id)
		   ("exec" . "funcall")
		   ("function" . ,fn)
		   ("args" . ,(mapcar #'convert-before-serialize args))
		   ))
    (wait-notification thread-id)))

(defun xcrypt-init (&rest libs)
  (unless libs (setq libs (list "core")))
  ;; Initialize tables
  (setq *notification-table* (make-hash-table :test #'equal))
  (setq *function-table* (make-hash-table :test #'equal))
  ;; Close old connection
  (when *perl-socket* 
    (close *perl-socket*)
    (setq *perl-socket* nil))
  ;; Generate communicator.xcr from temp.xcr
  (generate-communicator-script "temp.xcr" "communicator.xcr" libs)
  ;; Run Xcrypt
  (mp:process-run-function "Xcrypt" #'command-line "xcrypt" :args '("--nodelete_in_job_file" "--lang" "lisp" "temp.xcr"))
  (sleep 5)
  ;; Make connection with the Xcrypt process
  (make-connection-to-perl)
  )

(defun xcrypt-finish ()
  (when *perl-socket*
    (xcrypt-send '(("exec" . "finish")))
    (close *perl-socket*)
    (setq *perl-socket* nil)
    (setq *notification-table* nil)
    (setq *function-table* nil)
    (command-line "pkill" :args '("perl"))
    ))

;;;
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defmacro define-remote-call (package sym)
    (when (atom sym)
      (setq sym (list sym 
		      (format nil "~(~A~)" (symbol-name sym)))))
    (let ((args-sym (gensym)))
      `(defun ,(car sym) (&rest ,args-sym)
	 (apply #'xcrypt-call  ,(format nil "~A::~A" package (cadr sym))
		,args-sym)))))

;;; Define wrappers of Xcrypt functions
(define-remote-call "builtin" submit)
(define-remote-call "builtin" sync)
(define-remote-call "jobsched" (get-job-status "get_job_status"))

(defun prepare (tmpl)
  (dolist (key '(:before_in_job :exe :after_in_job))
    (awhen (assoc key tmpl)
      (unless (stringp (cdr it))
        (rplacd it (format nil "~S" (cdr it))))))
  (xcrypt-call "builtin::prepare" tmpl))

(defun prepare-submit (template)
  (submit (prepare template)))
(defun prepare-submit-sync (template)
  (sync (submit (prepare template))))

;;;
(defun serialize (obj)
  (if (consp obj)
      (format nil "(~A . ~A)" (serialize (car obj)) (serialize (cdr obj)))
    (let ((s (format nil "~S" obj)))
      (cond ((and (>= (length s) 1)
                  (char= #\# (aref s 0)))
             (format nil "~S" s))
            ((keywordp obj)
             (lisp2perl-keyname obj))
            (t s)
            ))))

(defun lisp2perl-keyname (key)
  (let ((lower-mode t)
        (name (symbol-name key)))
    (with-output-to-string (s)
      (write-char #\" s)
      (loop for i from 0 upto (1- (length name))
          do (let ((ch (aref name i)))
               (cond
                ((and (char= ch #\-)
                      (< i (1- (length name)))
                      (char= (aref name (1+ i)) #\-))
                 (incf i)
                 (write-char #\_ s))
                ((char= ch #\+)
               (setq lower-mode (not lower-mode)))
                (lower-mode
                 (format s "~(~C~)" ch))
                (t
                 (format s "~:@(~C~)" ch))
                )))
      (write-char #\" s)
      )))

;;; Interactive command
(defun xcrypt-clean ()
  (command-line "xcryptdel" :args '("--clean")))
(defun qstat ()
  (command-line "qjobs"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; When *module-mode*, load given modules, 
;;; make a connection to Perl, and wait for messages from Perl
(when *module-mode*
  (loop for mod in *xcrypt-modules*
      do (load (make-pathname
		:name mod :type "lisp"
		:directory (append (pathname-directory *load-pathname*)
                                   '("lib")))))
  (let ((dispatcher-thread (make-connection-to-perl)))
    (if dispatcher-thread
        (progn
          (format t "Successfully connected to Perl~%")
          (mp:process-wait "Waiting" #'(lambda () nil)))
      (error "Failed to connect to perl process.")))
  )
