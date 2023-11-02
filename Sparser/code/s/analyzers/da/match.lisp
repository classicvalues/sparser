;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1995,2011-2013,2020-2021  David D. McDonald  -- all rights reserved
;;;
;;;     File:  "match"
;;;   Module:  "analyzers;DA:"
;;;  Version:  February 2021

;; initiated 5/5/95.  Elaborated ..5/12. 11/3/11 Fixing match against
;; multiple words as tt.  7/17/13 Cleaning up, elaborating debugging.
;; 9/19/13 Moved out look-under code to objects/chart/edge-vectors/peek.

(in-package :sparser)

(defvar *edge-tt* nil)
(defvar *word-tt* nil)
(defvar *multiple-edges-over-word* nil)
(defvar *boundary-tt* nil)

(defun initialize-tt-state-description ()
  (setq *edge-tt* nil
        *word-tt* nil
        *multiple-edges-over-word* nil
        *boundary-tt* nil))

(defun setup-tt-type (tt)
  "Called by compare-tt-to-arc-set on the treetop that was passed to
   it from get-next-treetop. That function uses next-treetop/rightward,
   which notices whether the position has multiple-initial-edges.
   If it does, it returns a list of the preterminal-edges on the position"
  (initialize-tt-state-description)
  (etypecase tt
    (edge (setq *edge-tt* tt))
    (word (setq *word-tt* tt))
    (cons (setq *multiple-edges-over-word* tt))
    (symbol (setq *boundary-tt* tt))))


(defun setup-tt-type/pattern (pattern-item)
  ;; A way to use the standard mechanism that the search
  ;; uses but when working with patterns rather than the chart.
  (initialize-tt-state-description)
  (etypecase pattern-item
    ((or referential-category category mixin-category)
     (make-edge :category pattern-item))
    (word pattern-item)
    (symbol
     ;; e.g. :end-of-source
     (setq *boundary-tt* pattern-item))))



(defun arc-matches-tt? (arc tt)
  "Called from the compare-tt-to-arc-set function which determined
   which arc to compare against this treetop"
  (declare (special *da-execution* *trace-da-match*))
  (tr :arc-matches-tt? arc tt)
  (when *trace-da-match*
    (format t "   *edge-tt* = ~a~%   *word-tt* = ~a~
             ~%   *multiple-edges-over-word* = ~a~%   *boundary-tt* = ~a~
             ~%   The arc ~a is a ~a~
             ~%   tt = ~a"
            *edge-tt* *word-tt* *multiple-edges-over-word*
            *boundary-tt* arc (type-of arc) tt))
  ;; (push-debug `(,arc ,tt)) ;;(break "arc type")
  ;; (setq arc (car *) tt (cadr *))  
  (let ((match?
         (cond (*multiple-edges-over-word*
                (loop for e in *multiple-edges-over-word*
                   when (test-arc-against-tt arc e)
                   return t))
               (t
                (test-arc-against-tt arc tt)))))
    (if match?
      (tr :arc-matches-tt?/matches)
      (tr :arc-matches-tt?/no-match))
    match? ))


(defun test-arc-against-tt (arc tt)
  (declare (special *da-execution*))
  
  (typecase arc
    
    (form-arc
     (when *edge-tt*
       (or (eq (edge-form tt) (arc-label arc))
           ;; a significant number of categories are have both
           ;; referential-category and form-category aspects,
           ;; e.g. number -- so check the category as well
           (eq (edge-category tt) (arc-label arc)))))

    (label-arc
     (cond
       (*edge-tt*
        (eq (edge-category tt) (arc-label arc)))
       (t
        (when *da-execution*
          (da/look-under-edge tt (arc-label arc))))))

    (morph-arc
     (when *word-tt*
       (eq (word-morphology tt) (arc-morph-keyword arc))))

    (word-arc
     (cond
       (*word-tt*
        (eq tt (arc-word arc)))
       (*edge-tt*
        (let ((left-daughter (edge-left-daughter tt)))
          (when (word-p left-daughter)
            (eq left-daughter (arc-word arc)))))
       (t nil)))

    (polyword-arc
     (when *edge-tt*
       (eq (edge-category tt) (arc-polyword arc))))

    (unknown-word/s-arc
     (when *word-tt*
       (or (= 1 (arc-number-of-words arc))
           (then
             (break "stub: arc for multiple unknown words")
             nil))))

    (gap-arc
     (push-debug `(,arc ,tt))
     (break "stub: gap arc encountered"))

    (otherwise
     (push-debug `(,arc ,tt))
     (error "Unknown type of DA arc: ~a~%  ~a"
            (type-of arc) arc) )))




(defparameter *allow-da-to-look-under-edges* t)

(defun da/look-under-edge (edge label)
  ;; Called from Arc-matches-tt? when a treetop edge is being
  ;; compared against its category label and there is not a
  ;; match.
  (declare (special *da-search-is-going-leftwards*))
  (when *allow-da-to-look-under-edges*
    (if *da-search-is-going-leftwards*
      (da/look-under-edge/leftwards edge label)
      (da/look-under-edge/rightwards edge label))))

