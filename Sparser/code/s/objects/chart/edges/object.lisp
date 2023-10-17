;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1992-1999,2012-2023  David D. McDonald  -- all rights reserved
;;; extensions copyright (c) 2006-2007 BBNT Solutions LLC. All Rights Reserved
;;; 
;;;     File:  "object"
;;;   Module:  "objects;chart:edges:"
;;;  Version:  September 2023

;; 3.0 (9/3/92 v2.3) flushed the fields used by earlier psp algorithms
;; 3.1 (5/14/93) Allowed Set-used-by to make a list to help redundancy checking
;;      in the all-edges protocol
;; 3.2 (6/15) added predicate Edges-all-chain, find/edge-with-category
;;     (12/28) added 1st-preterminal-at. (12/31) added Top-edge-starting-at
;;     (3/13/94) added Set-used-by/anonymous-daughters
;;     (3/23) added Edge-spanning  (3/30) added All-preterminals-at
;;     (4/5) added Words-between.  (5/24) added Preterminal-edge-at?
;;     (6/9) added Edge-spans-region  (7/11) added Edge-between  
;;     (7/13) added One-word-long?  (7/27) added case in Edge-between
;; 3.3 (1/3/95) changed the semantics of Top-edge-starting-at to access the vector
;;      in the case of ambiguous single-term-edges rather than just be sugar for 
;;      the field in the edge-vector
;;     (8/30) added literal-edge? and dotted-edge?, added hook to suppress
;;      selected daughters from the discourse history
;;     (11/9) added Top-edge-used-in. (1/16/96) added Edge-subsumes-edge?
;; 3.4 (6/8/99) modified Set-used-by/anonymous-daughters to return the edges
;;      it sees as its value (but not the nodes or multiple-initial-edges,
;;      which may or may not end up being a problem).
;; 3.5 (3/31/06) added constituents field. 4/6 added spanned-words.
;;     (2/22/07) added edge-length. (3/15/12) quieting compiler
;;     (1/23/13) added continuous-edges-between (7/30/13) added edges-higher-than
;;     (9/19/13) moved find/edge-with-category to edge-vectors/peek to consolidate
;;      the operation down to one function.
;;     (8/30/14) added adjacent-edges?
;; 6/5/2015 check for empty seto of edges in highest-preterminal-at, to avoid error
;;     (11/6/15) added word-under-edge (11/12/15) added edge-sort

(in-package :sparser)

;;;-------------
;;; the object
;;;-------------

(defstruct (edge
            (:print-function print-edge-structure))

  category
  form
  referent

  starts-at  ;; edge vector
  ends-at    ;; edge vector

  rule
  left-daughter
  right-daughter

  used-in

  position-in-resource-array

  constituents ;; list of more than one edge for S2

  spanned-words

  mention ;; structure that contains the initial edge-referent and any contextual extensions

  )


(defvar *right-daughter-keywords*
  '(:single-term :context-sensitive :digit-based-number
    :number-fsa :long-span :literal-in-a-rule))


(defun subvert-edge (edge category &key form referent)
  "The caller has a good reason to flush the content of this edge
   and replace it with new content, and is in a context where the
   usual move of respanning would lead to more complications
   than committing this ugly hack."
  ;; used in convert-ordinary-word-edge-to-proper-name
  ;; /// workout implication for mentions, if any given the use-case
  (setf (edge-category edge) category)
  (when form
    (setf (edge-form edge) form))
  (when referent
    (set-edge-referent edge referent))
  edge)

;;;-------------------------------------------------------
;;; single code locus for setting the referent of an edge
;;;-------------------------------------------------------

(defun set-edge-referent (edge value &optional (create-mention nil) dependencies category)
  "The single point in the code that's entitled to setf the
   referent of and edge. Provides locus for associated actions
   like updating edge mentions. The 'value' is to be the
   referent of the' edge'."
  (declare (special *description-lattice*))
  (when *description-lattice*
    ;; When using the description lattice, the referent on an edge
    ;; should never be referential-category, except for specially
    ;; noted cases
    (when (referential-category-p value)
      (unless (allowable-referential-edge? edge value)
        (setf value
              (find-or-make-lattice-description-for-ref-category value)))))
  (cond ((and (edge-referent edge)
              (typep (edge-mention edge) 'discourse-mention))
         ;; If the edge already has a referent still have to update the mention
         (setf (edge-referent edge) value)
         (update-edge-mention-referent edge value))
        (dependencies
         (make-mention value edge category dependencies)
         (setf (edge-referent edge) value))

        (t (when create-mention
             (unless (or
                      (typep (edge-mention edge) 'discourse-mention)
                      (not (individual-p value))
                      (null (indiv-old-binds value)))
               (make-mention value edge)))
           (setf (edge-referent edge) value)))
  value)

(defun allowable-referential-edge? (edge value)
  "Should edges of this form that have categories for referents
   retain that referent (vs. have it converted to an individual)"
  (or (member (form-cat-name edge)
              '(preposition spatial-preposition
                comparative superlative
                spatio-temporal-preposition))
      (allowable-referential-value? value)))

(defun allowable-referential-value? (value)
  "Checks whether the category value passed in is one of the
   one for which it is appropriate to not create instances of."
  (when (category-p value) ;;/// perhaps an assert would be better
    (itypep value 'wh-pronoun)))



;;;-----------------------------------
;;; predicates for unusual edge-types
;;;-----------------------------------

#| A "literal" edge has a word as its label, i.e. as the
value of its category field. These edges are created by
make-edge-over-literal during the sweep that introduces
edges over words into the chart (see note in that function).
The are also used with abbreviations, particularly in the
routines that recognize proper names (PNF), where the
abbreviated form of a word (e.g. "Mr.") will be respanned
by an edge with the full form ("Mister"). The relevant
code is make-edge-over-abbreviation and its feeders. |#

(defun literal-edge? (edge) ;;/// not the best name
  (when (edge-p edge)
    (word-p (edge-category edge))))

(defun edge-for-literal? (e)
  ;; This field accessor is probably faster than
  ;; the type check, and its more definitive about
  ;; the fact that we're dealing with a literal,
  ;; i.e. a word directly referenced in a rule.
  (eq :literal-in-a-rule (edge-right-daughter e)))

(defgeneric edge-over-function-word? (edge)
  (:documentation "Does this edge correspond to a function word,
     i.e. does it directly dominate a word that was marked as
     a function-word when it was defined.")
  (:method ((n integer))
    (edge-over-function-word? (edge# n)))
  (:method ((e edge))
    (let ((w (edge-left-daughter e)))
      (when (word-p w)
        (get-tag :function-word w)))))


;;;-----------------------------------
;;; looking up the word under an edge
;;;-----------------------------------

(defun word-from-edge (e)
  "Walk down from an edge and return the word it
  dominates. Written for do-integrated-wf-count so the
  edges will correspond to singletons or small trees"
  (declare (special *number-word*))
  (cond
    ((word-p e)
     e)
    ((edge-p e)
     (cond
       ((eq (form-cat-name e) 'proper-name)
        (word-from-proper-name-edge e))
       (t
        (let ((left-daughter (edge-left-daughter e)))
          (word-from-edge-left-daughter left-daughter e)))))
    (t
     (break "argument 'e' is neither a word nor an edge:~
           ~% ~a  ~a" e (type-of e)))))
  
;; Perhaps convert these to flet's when dust has finally settled

(defun word-from-proper-name-edge (e)
  ;; For a company or other sort of proper-name (formed by PNF)
  ;; the edge's left-daughter is a red-herring
  ;; Looks like its easy to get a string from companies, people
  ;; locations, .. and we could find/make polywords from those
  ;; strings. Alternatively we could lump them like we do numbers
  (let* ((referent (edge-referent e))
         (name (value-of 'name referent)))
    (unless name (break "no 'name' on proper name ~a" e))
    (let* ((sequence (value-of 'sequence name))
           (string (string/sequence sequence)))
      (or (polyword-named string)
          (define-polyword-any-words string)))))


(defun word-from-edge-left-daughter (left-daughter e)
  (cond
    ((word-p left-daughter) ; "how"
     left-daughter)
    ((edge-p left-daughter)
     (let* ((category (edge-category left-daughter))
            (referent (edge-referent left-daughter)))
       (cond
         ((itypep referent 'number)
          *number-word*)
         ((polyword-p (edge-category left-daughter))
          (edge-category left-daughter))
         
         ((itypep referent 'geographical-region)
          (let ((name (value-of 'name referent)))
            (unless name
              (break "no 'name' on referent"))
            (if (polyword-p name)
              name
              (break "name is not a polyword"))))

         (t (break "another edge case: ~a" e)))))
    (t (break "left-daughter neither a word nor an edge:~
              % ~a  ~a" left-daughter (type-of left-daughter)))))



;;;----------------------
;;; special Set routines
;;;----------------------

(defun set-used-by (daughter parent)
  "Set the used-in field of the daughter edge to 
   the parent edge."
  (when (eq (edge-used-in parent) daughter)
    (warn "circularity detected in set-used-by")
    (return-from set-used-by nil))
  (cond
    ((null daughter)
     (error "null daughter in set-used-by"))
    (t
     (setf (edge-used-in daughter) parent))))


(defun top-edge-used-in (daughter-edge)
  ;; useful decoder of the field when you don't care about all the
  ;; edges but just the most recent one, e.g. in Do-treetop-triggers
  (let ((field (edge-used-in daughter-edge)))
    (when field
      (etypecase field
        (edge field)
        (cons (first field))))))


(defun set-used-by/anonymous-daughters (starting-position
                                        final-position
                                        parent-edge)
  ;; Called from Make-edge/all-keys when the left and right
  ;; daughters are not given explicitly. We go through the
  ;; treetops between the starting and ending positions and
  ;; mark them as used-by the parent edge.
  (let ((ending-position starting-position)
        (index-of-final-position (pos-token-index final-position))
        (first-tt? t)
        e/w  edges )
    (loop
      (setq e/w (right-treetop-at ending-position))
      (etypecase e/w
        (null)
        (edge
         (let ((edge-end-pos (pos-edge-ends-at e/w)))
           (when (> (pos-token-index edge-end-pos) index-of-final-position)
             ;; If there are unaccounted for edges within the
             ;; span, e.g. from no-space operations, then the
             ;; treetop-at call can go too far. 
             (return))
           (set-used-by e/w parent-edge)
           (setq ending-position edge-end-pos)
           (push e/w edges)))
        (word (setq ending-position
                    (chart-position-after ending-position)))
        ((eql :multiple-initial-edges)
         (dolist (e (all-preterminals-at ending-position))
           (set-used-by e parent-edge))
         (setq ending-position (chart-position-after ending-position))))
      (when first-tt?
        (unless (edge-left-daughter parent-edge)
          (setf (edge-left-daughter parent-edge) e/w))
        (setq first-tt? nil))
      (when (eq ending-position final-position)
        (return))
      (when (> (pos-token-index ending-position)
               index-of-final-position)
        (break "treetop loop has gone past its final position")))
    edges ))


;;;-------------------
;;; Access functions
;;;-------------------

(defun edge# (index)
  (aref *all-edges* index))


(defun edges-between (p1 p2)
  "Returns all the edges that span between the two positions"
  (let ((ev1 (pos-starts-here p1))
        (ev2 (pos-ends-here p2))                  
        edge edges )
    (when (ev-top-node ev1)
      (dotimes (i (ev-number-of-edges ev1))
        (setq edge (elt (ev-edge-vector ev1) i))
        (when (eq (edge-ends-at edge) ev2)
          (push edge edges))))
    edges ))

(defun edge-between (p1 p2)
  "Returns just one edge, the topmost edge spanning the two
   positions. If there is no such edge it returns nil."
  (when (eq p1 p2)
    (error "Positions to find the edge-between are identical: ~a" p1))
  (let* ((ev1 (pos-starts-here p1))
         (ev2 (pos-ends-here p2))
         (topmost-at-p1 (ev-top-node ev1)))
    (cond ((and (eq topmost-at-p1 :multiple-initial-edges)
		(<= (ev-number-of-edges ev1) 0))
	   (break "~&no edges between position ~s and ~s~&" p1 p2)
	   nil)
	  (topmost-at-p1
	   (when (eq topmost-at-p1 :multiple-initial-edges)
	     (setq topmost-at-p1 (elt (ev-edge-vector ev1)
				      (1- (ev-number-of-edges ev1)))))
	   (when (eq (edge-ends-at topmost-at-p1)
		     ev2)
	     topmost-at-p1)))))


(defun continuous-edges-between (p1 p2)
  "The caller has looked at the coverage between these positions
   (e.g. segment boundaries) and knows they're contiguous"
  (let ((start-pos p1)
        end-pos  edge   edges )
    (loop
      (setq edge (top-edge-starting-at start-pos))
      (push edge edges)
      (setq end-pos (pos-edge-ends-at edge))
      (when (eq end-pos p2)
        (return))
      (setq start-pos end-pos))
    (nreverse edges)))



(defun preterminal-edge-at? (pos-before)
  "just a predicate. If there is any edge of any kind
   over the word after this position, return non-nil"
  (ev-top-node (pos-starts-here pos-before)))


(defun 1st-preterminal-at (p)
  "Return the 1st edge to have spanned the word at position 'p'.
   If there were multiple edges over that word we ignore that."
  (declare (special *edge-vector-type*))
  (let ((ev (pos-starts-here p)))
    (ecase *edge-vector-type*
      (:kcons-list
       (break "write the code for the kcons variation"))
      (:vector
       (aref (ev-edge-vector ev) 0)))))


(defun highest-preterminal-at (p)
  "finds the edge at the largest index in the vector"
  (declare (special *edge-vector-type*))
  (let* ((ev (pos-starts-here p))
         (next-position (chart-position-after p))
         (max (ev-number-of-edges ev))
         (vector (ev-edge-vector ev)))
    (ecase *edge-vector-type*
      (:kcons-list
       (break "write the code for the kcons variation"))
      (:vector
       (when (and max (> max 0))
         (do* ((i (decf max) (decf max))
               (edge (aref vector i) (aref vector i)))
              ((< i 0))
           (when (eq (pos-edge-ends-at edge) next-position)
             (return edge))))))))


(defun all-preterminals-at (p)
  "Collect up a list of every single-term edge starting at p"
  (let* ((ev (pos-starts-here p))
         (next-position (chart-position-after p))
         (max (ev-number-of-edges ev))
         (vector (ev-edge-vector ev))
         edge  edges )
    (dotimes (i max)
      (setq edge (aref vector i))
      (if (eq (pos-edge-ends-at edge) next-position)
        (push edge edges)
        (return)))
    (nreverse edges)))



;;;------------------------------------
;;; Position-relative access functions
;;;------------------------------------

(defun edge-starting-position (position)
  (ev-position (edge-starts-at position)))

(defun edge-ending-position (position)
  (ev-position (edge-ends-at position)))


(defun edges/starting-at (position)
  (pos-starts-here position))

(defun edges/ending-at (position)
  (pos-ends-here position))

(defun top-edge-starting-at (position)
  "Until 1/3/95 this was just sugar for the field value. Now
   it's literally the topmost edge, ignoring the possibility of
   the caller wanting to worry about lexical ambiguities."
  (top-edge-on-ev (pos-starts-here position)))


(defun edge-spanning (start-pos end-pos)
  "Walk down the start position vector untill we hit an
   edge that ends at the end-pos. Return nil if there is
   no such edge."
  (let* ((ev (pos-starts-here start-pos))
         (count (ev-number-of-edges ev))
         (array (ev-edge-vector ev))
         edge )
    (dotimes (i count nil)
      (setq edge (aref array i))
      (when (eq (pos-edge-ends-at edge) end-pos)
        (return edge)))))


(defun edge-scopes-word (edge pos-before)
  "An instance of a word being defined by the position before
   it, this checks whether the edge covers the word"
  (let ((start (pos-token-index (pos-edge-starts-at edge)))
        (end (pos-token-index (pos-edge-ends-at edge)))
        (p (pos-token-index pos-before)))
    (and (<= start p)
         (< p end))))


(defmethod edges-higher-than (ev index)
  "The index is the location of an edge returned by
   index-of-edge-in-vector. Return a list of all
   the edges above that"
  (let ((array (ev-edge-vector ev)) ;; zero based
        (count (ev-number-of-edges ev)))
    (loop as i from (1+ index) to (1- count)
      collect (aref array i))))


(defun show/edges/ending-at (position)
  (let* ((ev (edges/ending-at position))
         (count (ev-number-of-edges ev))
         (array (ev-edge-vector ev)))
    (dotimes (i count ev)
      (format t "~&~A~%" (aref array i)))))

(defun show/edges/starting-at (position)
  (let* ((ev (edges/starting-at position))
         (count (ev-number-of-edges ev))
         (array (ev-edge-vector ev)))
    (dotimes (i count ev)
      (format t "~&~A~%" (aref array i)))))


(defun starting-edge (position number)
  "Return the 'number'th edge in the vector of edges that
   start at this position."
  (let ((ev (edges/starting-at (chart-position position))))
    (unless ev
      (error "No edges starting at position ~A" position))
    (let ((array (ev-edge-vector ev))
          (max   (ev-number-of-edges ev)))
      (unless (<= number max)
        (error "There is no ~Ath edge starting at position ~A"
               number position))
      (aref array number))))


;;;------------
;;; predicates
;;;------------

(defun one-word-long? (edge)
  (= 1 (edge-length edge)))

#| Alternatives
  (or (eq (edge-right-daughter edge) :literal-in-a-rule)
        ;; or :single-term or ??
      (= 1 (number-of-terminals-between (pos-edge-starts-at edge)
                                        (pos-edge-ends-at edge)))) |#

(defun word-under-edge (edge)
  "The caller has determined that this edge is one word long.
   Return that word."
  (pos-terminal (pos-edge-starts-at edge)))


(defun includes-edge-with-label (label list-of-edges)
  ;; analog of the Member function
  (dolist (edge list-of-edges nil)
    (when (eq label
              (etypecase edge
                (edge (edge-category edge))
                (word edge)))
      (return-from includes-edge-with-label edge))))


(defun edges-all-chain (position start/end)
  "Using the edge-used-in link to determine whether or not
   all of the edges that start (or end) at this position
   are in a single tree."
  (declare (special *edge-vector-type*))
  (let* ((ev (ecase start/end
               (:start (pos-starts-here position))
               (:end (pos-ends-here position))))
         (vector (ev-edge-vector ev))
         (count (ev-number-of-edges ev))
         lower-edge  edge )

    (if (<= count 1)
      t
      (ecase *edge-vector-type*
        (:kcons-list
         (break "write code for kcons-list case"))
        (:vector
         (setq lower-edge (aref vector 0))
         (dotimes (i (1- count))
           (setq edge (aref vector (1+ i)))
           (when (not (eq (edge-used-in lower-edge)
                          edge))
             (return-from edges-all-chain nil))
           (setq lower-edge edge))
         t )))))



(defun edge-spans-region (e start-pos end-pos)
  (and (edge-p e)
       (eq start-pos (pos-edge-starts-at e))
       (eq end-pos (pos-edge-ends-at e))))



;;;------------------------------
;;; position-relative predicates
;;;------------------------------

(defun edge-precedes (left-edge right-edge)
  "Does left edge end before (or on the same position as) right edge
   starts"
  ;; had some cases where there were discourse-mentions whose 'source'
  ;; was the cons (LINK-IN_EDGE ...)
  (when (and (edge-p left-edge)
             (edge-p right-edge))
    (let ((left-end (pos-edge-ends-at left-edge))
	  (right-start (pos-edge-starts-at right-edge)))
      (cond ((eq left-end right-start)
	     t)
	    ((position-precedes left-end right-start)
	     t)
	    (t nil)))))


(defun disjoint-edges (e1 e2)
  "These edges do not overlap. Their order in the chart should
   not matter"
  (if (edges-have-same-span? e1 e2)
    nil
    (else ;; so one of them has to be to the right of the other
      (let ((e1-precedes (edge-precedes e1 e2)))
        (if e1-precedes
          ;; the does e1 end before e2 starts?
          (position/<= (pos-edge-ends-at e1) (pos-edge-starts-at e2))
          ;; else, e2 should end before e1 starts
          (position/<= (pos-edge-ends-at e2) (pos-edge-starts-at e1)))))))
          
    

(defmethod to-the-right-of ((e1 edge) (e2 edge))
  ;; methods for other signatures in positions/positions.lisp
  (to-the-right-of (pos-edge-ends-at e1) (pos-edge-ends-at e2)))


;; (sort <list of edges> #'edge-sort)
(defun edge-sort (e1 e2)
  (if (edge-precedes e1 e2) e1 e2))


(defun adjacent-edges? (left-edge right-edge)
  (eq (pos-edge-ends-at left-edge)
      (pos-edge-starts-at right-edge)))


(defun edge-subsumes-edge? (higher-edge lower-edge)
  "Checks whether the putative higher edge completely covers
   the lower edge."
  (when (<= (pos-token-index (pos-edge-starts-at higher-edge))
            (pos-token-index (pos-edge-starts-at lower-edge)))
    (when (>= (pos-token-index (pos-edge-ends-at higher-edge))
              (pos-token-index (pos-edge-ends-at lower-edge)))
      t )))

(defun edges-have-same-span? (e1 e2)
  "Do these two edges start and end at the same positions?"
  (and (eq (edge-starts-at e1) (edge-starts-at e2))
       (eq (edge-ends-at e1) (edge-ends-at e2))))


(defun edge-length (edge)
  (- (pos-token-index (ev-position (edge-ends-at edge))) 
     (pos-token-index (ev-position (edge-starts-at edge)))))


;;;---------------
;;; vetting edges
;;;---------------

(defun single-best-edge-over-word (pos-before)
  (let ((result (only-nontrivial-edges
                 (all-preterminals-at pos-before))))
    (unless result
      (push-debug `(,(all-preterminals-at pos-before) ,pos-before))
      (break "Shouldn't happen: check for non-trivial edges returned 'nil'"))

    (typecase result
      (cons (highest-preterminal-at pos-before))
      (edge result)
      (otherwise
       (break "New type of result: ~a" result)))))


(defun single-best-edge-from-vector (ev)
  ;; Assumes we have a 'starting-at' vector.  Only makes sense
  ;; when there's an ambiguity, so also assuming the relevant edges
  ;; span only one word
  (single-best-edge-over-word (ev-position ev)))

;;--- literals

(defun only-nontrivial-edges (list-of-edges)
  ;; version threaded from Single-best-edge-over-word
  (declare (special category::capitalized-word))
  (let ( vetted-edges  label )
    (dolist (edge list-of-edges)
      (setq label (edge-category edge))

      ;; no literals
      (unless (word-p label)
        ;; no morph edges
        (unless (eq label category::capitalized-word)
          (push edge vetted-edges))))

    (when vetted-edges
      (let ((edges (nreverse vetted-edges)))
        (if (cdr edges)
          (prefer-edge-referring-to-terms edges)
          (list (first edges)))))))

;;moved from DMP/scan which is not normally loaded

(defun prefer-edge-referring-to-terms (list-of-edges)
  ;; version threaded from Single-best-edge-over-word
  ;; handles problem of "first" taken as an ordinal vs. reified
  ;; as a term (e.g. "Disk First Aid")
  (let ( term-edges class-edges )
    (dolist (edge list-of-edges)
      (cond
       ((individual-p (edge-referent edge))
        (push edge term-edges))
       ((category-p (edge-referent edge)) ;; e.g. from Comlex
        (push edge class-edges))))

    (cond
     ((and term-edges (cdr term-edges)) ;; check for null class-edges?
      (take-top-edge-if-they-chain term-edges))
     (t (or term-edges
            class-edges)))))


(defun take-top-edge-if-they-chain (list-of-edges)
  ;; presupposing these are all the same length or start at the same position
  (let ((start-pos (pos-edge-starts-at (first list-of-edges))))
    (if (edges-all-chain start-pos :start)
      (list (ev-top-node (pos-starts-here start-pos)))
      (check-for-all-being-number-edges list-of-edges))))


;;;---------------------------
;;; special purpose functions
;;;---------------------------

(defun check-for-all-being-number-edges (list-of-edges)
  (let ((all-numbers? t)  representative-edge  )
    (dolist (edge list-of-edges)
      (typecase (edge-category edge)
        ((or referential-category category mixin-category)
         (case (cat-symbol (edge-category edge))
           (category::number          (setq representative-edge edge))
           (category::digit-sequence  (setq representative-edge edge))
           (category::ones-number     (setq representative-edge edge))
           (category::tens-number     (setq representative-edge edge))
           (category::teens-number    (setq representative-edge edge))
           (category::multiplier      (setq representative-edge edge))
           (otherwise
            (setq all-numbers? nil))))
        (word )
        (otherwise
         (setq all-numbers? nil))))

    (if all-numbers?
      (list representative-edge)
      (check-for-the-word-being-one list-of-edges))))


(defun check-for-the-word-being-one (list-of-edges)
  (let ((random-daughter (edge-left-daughter (second list-of-edges))))
    ;; in the problematic case (9/15 PT, token id 10,110) the word
    ;; "one" has gotten an interpretation as a term and the first
    ;; edge, 'number', has :multiple-initial-edges as its left-daughter
    (if (and (word-p random-daughter)
             (eq random-daughter (word-named "one")))

      (list (second list-of-edges))
      ;; has to be a list because Mine-head/edge? etc. take car's on it

      (prefer-capitalized-sequences list-of-edges))))


(defun prefer-capitalized-sequences (list-of-edges)
  ;; you can get a term and its capitalized version over the same word
  (let ((caps-edge
         (find (category-named 'capitalized-sequence)
               list-of-edges
               :key #'edge-category)))
    (if caps-edge
      (list caps-edge)

      ;; give up
      list-of-edges)))


(defun filter-literals (ev)
  ;; stand-alone version. Assumes we have a 'starting-at' vector,
  ;; otherwise we need a different edge-collector
  (let ( vetted-edges )
    (dolist (edge (all-preterminals-at (ev-position ev)))
      (unless (word-p (edge-category edge))
        (push edge vetted-edges)))
    (nreverse vetted-edges)))

