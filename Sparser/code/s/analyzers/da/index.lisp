;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1995,2013,2018,2020  David D. McDonald  -- all rights reserved
;;; 
;;;     File:  "index"
;;;   Module:  "analyzers;DA:"
;;;  Version:  November 2020

;; initiated 5/5/95.  Elaborated ..5/22.  5/30 added case to Find-word-in-tt-alist
;; 7/18/13 Patched around case of getting a list of edges.

(in-package :sparser)

;;;--------
;;; driver
;;;--------

(defun make-and-index-da-pattern (pattern rule)
  ;; Called from Setup-da-pattern once the pattern has been checked
  ;; that it doesn't duplicate any of the existing tries.
  ;;   We make the trie corresponding to the pattern and then
  ;; we hook it in.
  (let ((trie (create-and-thread-trie-for-pattern pattern rule)))
    (index-trie-by-1st-item trie)
    trie ))



;;;--------------------------------
;;; test used by the dispatch hook
;;;--------------------------------

(defun trie-for-1st-item (tt)
  ;; Called from Look-for-and-execute-any-DA-pattern as the
  ;; hook into the search machinery.
  (let ((primary-key
         (typecase tt
           (edge (edge-category tt))
           (word tt)
           (edge-vector 
            ;; this is arbitrary, but it gets rid of literals without
            ;; bothering to look, so it's a reasonable starting point.
            (highest-edge tt))
           (cons
            ;; case of two edges: literal for "of" and the
            ;; preposition form. ////find the code that defines
            ;; a preference and use it here.
            ;; This heuristically assumes the interesting one
            ;; is late in the list.
            (car (last tt)))
           (otherwise
            (push-debug `(,tt))
            (error "Unexpected type of treetop object: ~a~%  ~a"
                   (type-of tt) tt)))))

    (let ((trie-vertex
           (gethash primary-key
                    (da-trie-data-table-of-first-labels (da-trie)))))

      (when (and (null trie-vertex)
                 (edge-p tt))
        (let ((secondary-key (edge-form tt)))
          (setq trie-vertex
                (gethash secondary-key
                         (da-trie-data-table-of-first-labels (da-trie))))))

      trie-vertex )))


(defun trie-for-1st-item/pattern (pattern-item)
  ;; Same idea, but for use when working against patterns rather
  ;; than treetops, e.g. in Check-for-clash-with-other-da-rules
  (gethash pattern-item
           (da-trie-data-table-of-first-labels (da-trie))))



;;--- setting up that index

(defun index-trie-by-1st-item (vertex-0)
  (let ((1st-item (vertex-reference-item vertex-0))
        (table (da-trie-data-table-of-first-labels (da-trie))))
    (setf (gethash 1st-item table) vertex-0)))




;;;-----------------------------------------------------------
;;; index/predicate when searching a trie from the middle out
;;;-----------------------------------------------------------

(defun is-an-item-anywhere-in-a-trie (tt)
  ;; called from Look-for-and-execute-any-DA-pattern
  (let ((key (typecase tt
               (edge (edge-category tt))
               (word tt)
               (cons ;; see above
                (car (last tt)))
               (otherwise
                (push-debug `(,tt))
                (error "Unexpected type of treetop object: ~a~%  ~a"
                       (type-of tt) tt))))
        (table (da-trie-data-table-of-labels-anywhere (da-trie))))

    (let ((arcs (gethash key table)))
      (when arcs
        (when (tt-not-part-of-last-DA-pattern-to-fire tt)
          arcs )))))


(defun tt-not-part-of-last-DA-pattern-to-fire (tt)
  ;; called from Is-an-item-anywhere-in-a-trie. It looks up the
  ;; treetop in the alist and returns t if it isn't there.
  (declare (special *tt-alist*))
  (let ((result
         (etypecase tt
           (edge  (not (rassoc tt *tt-alist* :test #'eq)))
           (word  (not (find-word-in-tt-alist tt))))))
    ;(format t "~&not part of last pattern?  ~A~%" result)
    result ))

(defun find-word-in-tt-alist (word)
  (declare (special *tt-alist*))
  (let ( word-data )
    (dolist (entry *tt-alist* nil)
      (unless (edge-p (cdr entry))
        (setq word-data (cdr entry))
        (unless (symbolp word-data) ;; e.g. :end-of-source
          (when (eq (first word-data) word)
            (return-from find-word-in-tt-alist word-data)))))))



(defun index-item-as-somewhere-in-a-trie (item arc)
  ;; called from Make-arc-for-pattern-item
  (let* ((table (da-trie-data-table-of-labels-anywhere (da-trie)))
         (other-cases (gethash item table)))

    (setf (gethash item table)
          (if other-cases
            (add-if-not-a-duplication arc other-cases)
            (list arc)))))



(defun add-if-not-a-duplication (new-arc established-arcs)
  ;; Called from Index-item-as-somewhere-in-a-trie
  ;; If the arc doesn't duplicate any of the ones already indexed
  ;; to the item, then cons it onto the list of those arcs
  ;; and return that.
  ;;   Duplication (5/22) is (??) having the same left vertex.
  ;; There wouldn't be a right vertex available at this point
  ;; because this call originates in Make-arc-for-pattern-item,
  ;; which is called incrementally as the trie is built.
  ;;   We know they all involve the same item or we wouldn't
  ;; be here.

  (let ((new-arcs-left-vertex (arc-left-vertex new-arc)))
    (dolist (old-arc established-arcs)
      (when (eq new-arcs-left-vertex
                (arc-left-vertex old-arc))
        (return-from add-if-not-a-duplication established-arcs)))
    (cons new-arc established-arcs)))
      




;;;----------------------------------
;;; avoiding duplication of patterns
;;;----------------------------------

(defun check-for-clash-with-other-da-rules (rule pattern)
  (let ((first-item (first pattern)))
    (let ((trie (trie-for-1st-item/pattern first-item)))
      (when trie
        (let ((result
               (compare-trie-threading-with-pattern trie pattern)))
          result )))))
;; There's a serious missmatch what the match routine is doing
;; and what the now-ignored code is doing with the result.
;; SBCL noticed that you can't get a da-name off a keyword symbol.
;; This is supposed to run for side-effects.
;; /// needs systematic testing and sorting out what the compare
;; routine should really return such that something ilke this
;; would do the right thing, which is to announce the problem
;; and then resuse the earlier da-rule if the user says that's ok.
          #+ignore
          (if (eq result :identical)
            (then
              ;; This happens before the new rule object is interned,
              ;; and if the 1st call to define some rule died in the
              ;; middle, we might not be going through the explicit
              ;; 'redefine' route.
              (if (eq (da-name result) (da-name rule))
                nil
                (else
                  (cerror "Continue if you want the existing rule ~
                          renamed"
                          "The proposed pattern for the Debris Analysis ~
                           rule ~A~%is the same as the one for ~A.~
                          ~%~%.~%~%" rule result)
                  (setf (da-name result) (da-name rule))
                  rule )))
            nil )



(defun compare-trie-threading-with-pattern (vertex pattern)
  (let ((*da-execution* nil))
    (declare (special *da-execution*))
    (catch :da-pattern-clash-check
      (match-trie-against-pattern-identity vertex pattern))))

(defun match-trie-against-pattern-identity (vertex pattern)
  ;; Called from Check-for-clash-with-other-da-rules.
  ;; Recursively checks pattern elements against existing paths
  ;; through the trie.  At the first point of divergence it
  ;; throws nil back to the caller.
  (push-debug `(,vertex ,pattern))
  (when (end-vertex-p vertex)
    (if pattern
      ;; it's longer
      (throw :da-pattern-clash-check :new-pattern-is-longer)
      (throw :da-pattern-clash-check :identical)))

  (when (null pattern)
    ;; the pattern is shorter than the trie
    (throw :da-pattern-clash-check :new-pattern-is-shorter))

  (let ((1st-pattern-item (first pattern))
        (arc-set (vertex-rightward-extensions vertex))
        matching-arc )

    (dolist (arc arc-set)
      (setup-tt-type/pattern 1st-pattern-item)
      (when (arc-matches-tt? arc 1st-pattern-item)
        (setq matching-arc arc)))

    (if matching-arc
      (match-trie-against-pattern-identity (arc-right-vertex matching-arc)
                                           (rest pattern))
      (throw :da-pattern-clash-check vertex))))
