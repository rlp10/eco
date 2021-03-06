(in-package :cl-user)
(defpackage eco.parser
  (:use :cl :esrap)
  (:import-from :split-sequence
                :split-sequence-if)
  (:export :<block>
           :<expr-tag>
           :<else-tag>
           :code
           :body
           :parse-template
           :parse-pathname))
(in-package :eco.parser)

;;; Utilities

(defparameter +whitespace+
  (list #\Space #\Tab #\Newline #\Linefeed #\Backspace
        #\Page #\Return #\Rubout))

(defun whitespacep (char)
  (member char +whitespace+))

(defun trim-whitespace (str)
  (string-trim +whitespace+ str))

;;; Element classes

(defclass <tag> () ())

(defclass <expr-tag> ()
  ((code :reader code :initarg :code)))

(defclass <block-tag> (<tag>)
  ((code :reader code :initarg :code)))

(defclass <end-tag> (<tag>)
  ())

(defclass <else-tag> (<tag>) ())

(defclass <block> ()
  ((code :reader code :initarg :code)
   (body :reader body :initarg :body)))

;;; Parsing rules

(defrule block-string (+ (not "%>"))
  (:lambda (list) (text list)))

(defrule tag (and "<%" block-string "%>")
  (:destructure (open code close)
    (declare (ignore open close))
    (if (char= (elt code 0) #\=)
        (make-instance '<expr-tag>
                       :code (subseq (trim-whitespace code) 1))
        (let ((text (trim-whitespace code)))
          (cond
            ((equal text "end")
             (make-instance '<end-tag>))
            ((equal text "else")
             (make-instance '<else-tag>))
            (t
             (make-instance '<block-tag>
                            :code text)))))))

(defrule raw-text (+ (not "<%"))
  (:lambda (list) (text list)))

(defrule expr (+ (or tag raw-text)))

;;; Token parsing
;;; Take a list of either strings or <tag>s and turn it into a tree

(defun parse-tokens (tokens)
  (let ((tokens (copy-list tokens)))
    (labels ((next-token ()
               (prog1 (first tokens)
                 (setf tokens (rest tokens))))
             (rec-parse (&optional toplevel)
               (let ((out (make-array 1 :adjustable 1 :fill-pointer 0))
                     (tok (next-token)))
                 (loop while (and tok (not (typep tok '<end-tag>))) do
                   (vector-push-extend
                    (cond
                      ((typep tok '<block-tag>)
                       ;; Start a block
                       (make-instance '<block>
                                      :code (code tok)
                                      :body (rec-parse)))
                      (t
                       tok))
                    out)
                   (setf tok (next-token))
                   (if (and (not tok) (not toplevel)) ;; Next tok is nil
                       (error "Missing 'end' tag.")))
                 out)))
      (rec-parse t))))

;;; Interface

(defun parse-template (template-string)
  (parse-tokens (parse 'expr template-string)))

(defun slurp-file (path)
  ;; Credit: http://www.ymeme.com/slurping-a-file-common-lisp-83.html
  (with-open-file (stream path)
    (let ((seq (make-array (file-length stream) :element-type 'character :fill-pointer t)))
      (setf (fill-pointer seq) (read-sequence seq stream))
      seq)))

(defun parse-pathname (template-pathname)
  (parse-template (slurp-file template-pathname)))
