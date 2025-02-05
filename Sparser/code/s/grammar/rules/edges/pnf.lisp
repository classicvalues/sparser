;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1993-1994,2013-2016 David D. McDonald  -- all rights reserved
;;; 
;;;     File:  "pnf"
;;;   Module:  "analyzers;psp:edges:"
;;;  Version:  July 2016

;; initiated 5/28/93 v2.3)
;; 0.1 (2/24/94) added daughter and used-in encoding
;; 0.2 (9/28/94) added form parameter
;;     (8/16/13) Set the constituents field

;; 5/25/2015 added call to place-referent-in-lattice around computation of edge-referent field
;;  initial work to produce a lattice of descriptions
;;  the places where this call is put were determined by the methods where (complete edge) was also called

(in-package :sparser)


(defun edge-over-proper-name (starting-position
                              ending-position
                              category
                              form
                              referent
                              rule
                              daughters )

  ;; called from C&R-multi-word-span

  (let ((edge (next-edge-from-resource))
        (starting-vector (pos-starts-here starting-position))
        (ending-vector (pos-ends-here ending-position)))
                       
    (setf (edge-starts-at edge) starting-vector)
    (setf (edge-ends-at   edge) ending-vector)
    (knit-edge-into-positions edge starting-vector ending-vector)

    (setf (edge-category edge) category)
    (setf (edge-form edge)     form)

    (setf (edge-rule edge)     rule)

    (if daughters
      (dolist (item daughters)
        (when (edge-p item)
          (set-used-by item edge)))
      (mapcar #'(lambda (tt)
                  (when (edge-p tt)
                    (set-used-by tt edge)))
              (setq daughters
                    (successive-treetops :from starting-position
                                         :to ending-position
                                         :below edge))))

    (setf (edge-left-daughter edge) (first daughters))
    (setf (edge-right-daughter edge) :proper-name)
    (setf (edge-constituents edge) daughters)

    (set-edge-referent edge referent)
    (when *trace-edge-creation*
      (format t "~&creating ~A for a proper name"
              edge))
    

    (complete edge)
    (assess-edge-label category edge)

    edge ))
