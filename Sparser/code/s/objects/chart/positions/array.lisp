;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:(SPARSER LISP) -*-
;;; copyright (c) 1991-2005,2012-2018  David D. McDonald  -- all rights reserved
;;;
;;;     File:  "array"
;;;   Module:  "objects;chart:positions:"
;;;  Version:  January 2018

;; initialized 1/91
;; 2.0 (8/13/91 v1.9) added Still-in-the-chart
;; 2.1 (10/5/92 v2.3) extended re-initialize-position-array to also zero
;;      the assessed? field.
;; 2.3 (11/26) Added initialize-next-position-out, packaging a call from
;;      bump-&-store-word so it can be used in several places.
;; 2.4 (1/27/94) added Further-to-the-right. Wrote the obvious variation on
;;      making a chart that does it and the set all in one operation.
;; 2.5 (5/3) added initialization of display-char-index field
;;     (8/30) added Edge-is-still-in-chart. (2/14/05) added initialize-used-portion-of-chart
;;     (3/4/12) quiet compiler. 2/3/13 reclaim kons's on the status-info field.

(in-package :sparser)

;;;----------------------------------
;;;  creating a chart from scratch
;;;----------------------------------

(defvar *number-of-positions-in-the-chart* 40000
  "The number of words that can be parsed before the chart resource wraps.")

(defvar *make-chart-with-edge-vectors* t
  "Must be on if any parsing is to be done, but can be off if nothing beyond
word frequency or other word-level observations are required. If left off,
the chart will require markedly less space.")

(defun make-position-array ()
  (make-array *number-of-positions-in-the-chart*))

(defun make-the-chart ()
  (declare (special *the-chart*))
  (setq *the-chart* (make-a-chart)))

(defun make-a-chart ()
  (let ((array (make-position-array))
        position )
    (dotimes (n *number-of-positions-in-the-chart* array)
      (setq position (make-position :array-index n))

      (when *make-chart-with-edge-vectors*
        (setf (pos-ends-here position)
              (make-edge-vector
               :position position
               :direction :|ending at|))
        (setf (pos-starts-here position)
              (make-edge-vector
               :position position
               :direction :|starting at|)))

      (setf (elt array n) position))))

;;;--------------------------
;;;  per-run initializations
;;;--------------------------

(defun re-initialize-position-array ()
  (declare (special *the-chart*))
  (let ((chart *the-chart*)
        position )
    (dotimes (n *number-of-positions-in-the-chart*)
      (setq position (aref chart n))
      (setf (pos-terminal position) nil)
      (setf (pos-status-lifo position) nil)
      (setf (pos-assessed? position) nil))))


(defun initialize-position (p token-number)
  (setf (pos-character-index      p) nil)
  (setf (pos-display-char-index   p) nil)
  (setf (pos-token-index          p) token-number)
  (setf (pos-terminal             p) nil)
  (setf (pos-preceding-whitespace p) nil)
  (setf (pos-capitalization       p) nil)
  (when (consp (pos-status-lifo p))
    (kreclaim (pos-status-lifo p)))
  (setf (pos-status-lifo          p) nil)
  (setf (pos-assessed?            p) nil)
  (initialize-edge-vector (pos-ends-here p) p)
  (initialize-edge-vector (pos-starts-here p) p))


(defun initialize-used-portion-of-chart ()
  "Called during initialize-chart-state before starting "
  (declare (special *first-chart-position* *the-chart*
                    *next-chart-position-to-scan*
                    *position-array-is-wrapped*))
  (let ((start *first-chart-position*)
        (end *next-chart-position-to-scan*))
    (if *position-array-is-wrapped*
      (then
        ;;/// this isn't enough to make regular parsing
        ;; succeed. Probably have to clear the sentences
        ;; and possibly other document elements too
        (make-the-chart)) ;; throw it all away
      (else
        (do* ((i start (1+ i))
              (p (aref *the-chart* i) (aref *the-chart* i)))
             ((= i end))
          (initialize-position p (pos-token-index p)))))))



;;;---------------------------------------------
;;;  Accessing a terminal position in the chart
;;;---------------------------------------------

(defun chart-position (number)
  (declare (special *number-of-next-position* *position-array-is-wrapped*
                    *first-chart-position* *the-chart*))
  (when (> number *number-of-next-position*)
    (error "The position ~A is beyond the end of the chart" number))
  (if *position-array-is-wrapped*
    (then
      (if (< number *first-chart-position*)
        (error "The chart-position ~a is no longer available.~
                ~%   The chart array has wrapped around it."
               number)
        (let ((array-index
               (mod number *number-of-positions-in-the-chart*)))
          (aref *the-chart* array-index))))
    (else
      (when (> number
               *number-of-positions-in-the-chart*)
        (error "Attempt to access a position beyond the end of ~
                the chart.~%  position = ~A   length of chart = ~A"
               number *number-of-positions-in-the-chart*))
      (aref *the-chart* number))))


;;;--------------------------------------
;;;  Accessing an array cell in the chart
;;;--------------------------------------

(defun chart-array-cell (number)
  (declare (special *the-chart*))
  ;; syntactic sugar
  (aref *the-chart* number))


;;;--------------------------------------
;;; predicates over one or two positions
;;;--------------------------------------

(defun still-in-the-chart (token-index)
  (declare (special *position-array-is-wrapped* *first-chart-position*))
  ;; called by TTs to see where it can start.  We take it on
  ;; faith that they don't pass in a number beyond the end
  ;; of the chart
  (if *position-array-is-wrapped*
    (if (< token-index *first-chart-position*)
      nil
      t)
    t))

(defun edge-is-still-in-chart (edge)
  (declare (special *position-array-is-wrapped* *first-chart-position*
                    *first-token-index-still-in-chart*
                    *edge-resource-is-wrapped*))
  (let ((start-pos (pos-edge-starts-at edge)))
    (if *position-array-is-wrapped*
      (>= (pos-token-index start-pos)
          *first-token-index-still-in-chart*)
      (if *edge-resource-is-wrapped*
        (>= (pos-token-index start-pos)
            *first-token-index-still-in-chart*)
        t))))


(defun chart-position-after (p)
  (declare (special *the-chart*))
  (let ((array-index (pos-array-index p)))
    (cond ((= array-index *number-of-positions-in-the-chart*)
           ;; it's wrapping with the next scan
           (aref *the-chart* 0))
          ((= array-index (1- *number-of-positions-in-the-chart*))
           ;; there's an error when Bump-&-store-word is doing
           ;; position 249, ///have to look at this
           (aref *the-chart* 0))
          (t
           (aref *the-chart* (1+ array-index))))))

(defun chart-position-before (p)
  (declare (special *the-chart*))
  (let ((position-index (pos-array-index p)))
    (if (= position-index 0)  ;; it just wrapped
      (aref *the-chart* (1- *number-of-positions-in-the-chart*))
      (aref *the-chart* (1- position-index)))))

(defun chart-position-n-positions-before (n pos &aux (prior-pos pos))
  (loop for i from (1- n) downto 0
     do (setq prior-pos (chart-position-before prior-pos)))
  prior-pos)


(defun adjacent-positions (p1 p2)
  (let ((array-index-p1 (pos-array-index p1))
        (array-index-p2 (pos-array-index p2)))
    (cond ((= array-index-p2
              (1+ array-index-p1))
           t)
          ((= 0 array-index-p2)
           (= array-index-p1
              (1- *number-of-positions-in-the-chart*)))
          (t nil))))


(defun further-to-the-right (p1 p2)
  ;; does p1 have a higher token index than p2
  (let ((p1-index (pos-token-index p1))
        (p2-index (pos-token-index p2)))
    (< p2-index p1-index)))
