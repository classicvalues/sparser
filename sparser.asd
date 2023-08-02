;;; -*- Mode: Lisp; Syntax: Common-Lisp; -*-
;;; Copyright (c) 2016-2021 SIFT LLC. All Rights Reserved.

(defvar cl-user::script :default
  "The script specifies a set of Sparser parameters, switch values, grammar files, etc.
This variable must be set before loading Sparser to have the correct effect.")

(defsystem :sparser
  :depends-on (:cl-json :ddm-util :mumble :cl-ppcre)
  :components ((:file "Sparser/code/s/init/everything"))
  :perform (load-op :after (o c) (pushnew :sparser *features*))
  :in-order-to ((test-op (test-op :sparser/tests))))

#| This macrolet defines eight variations on the base Sparser system,
 corresponding to different scripts. See init/loaders/scripts.lisp
|#
(macrolet ((define-sparser-system (script)
             (let ((script-system (format nil "sparser/script/~(~a~)" script))
                   (sparser-system (format nil "sparser/~(~a~)" script)))
               `(progn
                  (defsystem ,script-system
                    :perform (load-op (o c) (setq cl-user::script ,script)))
                  (defsystem ,sparser-system
                    :depends-on (,script-system :sparser))))))
  (define-sparser-system :fire)
  (define-sparser-system :biology)
  (define-sparser-system :score)
  (define-sparser-system :acumen)
  (define-sparser-system :blocks-world)
  (define-sparser-system :grok)
  (define-sparser-system :c3)
  (define-sparser-system :no-grammar)
  (define-sparser-system :just-dm&p)
  (define-sparser-system :default))

(defsystem :sparser/tests
  :depends-on (:sparser)
  :components ((:file "test/rt")
               (:file "test/k-methods")
               (:file "test/subcategorization")
               (:file "test/semantic-structure"))
  :perform (test-op (o c)
             (let ((*package* (find-package :sparser)))
               (uiop:symbol-call :rt :do-tests))))

(defsystem :sparser/graph
  :depends-on (:sparser :cl-dot)
  :components ((:file "Sparser/code/s/objects/model/categories/graph")))
