;;; -*- Mode: LISP;  Package: MUMBLE; Syntax: Common-lisp; Base: 10 -*-

;;; MUMBLE-86:  interface > bundles > accessory-processing

;;; Copyright (C) 1985, 1986, 1987, 1988  David D. McDonald
;;;   and the Mumble Development Group.  All rights
;;;   reserved. Permission is granted to use and copy
;;;   this file of the Mumble-86 system for
;;;   non-commercial purposes.
;;; Copyright (c) 2006 BBNT Solutions LLC. All Rights Reserved
;;; Copyright (c) 2015-2017 David D. McDonald  -- all rights reserved

(in-package :mumble)

;;;-----------
;;; questions
;;;-----------

(defun process-wh-accessory (rspec)
  "The classic treatment of WH questions was to make them one of
   choices in the tree family, using phrases that were specialized
   to fit, and placed the WH phrase (maybe only the pronoun?) in
   a comp slot that was a peer to the main clause. Now we're doing
   essentially the same thing: the WH phrase goes into a comp
   slot that is a peer of the main clause, but we're doing it by
   attaching the slot on demand through a feature. Note that
   the the :wh feature takes a dtn ('rspec') as its value. 
   That dtn will be realized when it is reached in the traversal."
  (let ((ap (attachment-point-named 'wh-comp)))
    (attach rspec ap)))


(defun process-question-accessory ()
  "Rearranges the tense-modal attachment points to bring about
   the subject - auxilary inversion that defines questions.
   The inversion entails moving over the subject, but is
   only needed if there actually is a subject."
  (when (lexical-subject)
    (set-state *current-phrasal-root*
	       (change-state :aux-state 'prepose-aux
                             (state *current-phrasal-root*)))
    (let* ((cur-ap (splicing-attachment-point-named 'tense-modal))
	   (new-ap (splicing-attachment-point-named 'preposed-tense-modal))
	   (position (cdr (assoc cur-ap (available-aps *current-phrasal-root*)))))
      (setf (available-aps *current-phrasal-root*)
            (delete cur-ap (available-aps *current-phrasal-root*)))
      (push (cons new-ap position) (available-aps *current-phrasal-root*))))
  (add-label-to *current-position* 'question))


(defun process-wh-adjunct-accessory (value)
  ;;value is the specification of the adjunct being
  ;; questioned
  (let* ((ap (splicing-attachment-point-named 'wh-marker))
	 (active-ap
	   (assoc ap (available-aps *current-phrasal-root*)))
	 (position (cdr active-ap)))
    (attach-by-splicing ap position value)))

(defun lexical-subject ()
  (let* ((subject-position
	   (cdr (assoc 'subject (position-table *current-phrasal-root*))))
	 (contents (when subject-position (contents subject-position))))
    (when contents
      (typecase contents
        (ttrace nil)
        (t contents)))))

;;;----------
;;; command
;;;----------

(defun process-command-accessory ()
  (let ((root *current-phrasal-root*))
    (remove-subject root)
    (change-state
     ':aux-state 'unmarked (state root))))


;;;----------------------
;;; the auxiliary system
;;;----------------------

(defun return-tense-modal-attachment-point ()
  (case (state-value ':aux-state (state *current-phrasal-root*))
    (initial (splicing-attachment-point-named 'tense-modal))
    (prepose-aux (splicing-attachment-point-named 'preposed-tense-modal))))

(defun process-tense-modal-accessory (value)
  (let* ((ap (return-tense-modal-attachment-point))
         (position (position-of-ap ap))         
	 (contents
	   (cond ((or (eq value (accessory-value-named 'past))
		      (eq value (accessory-value-named 'present)))
		  (tense-marker-named (name value)))
		 ((wordp value)
                  (change-state ':aux-state 'unmarked (state *current-phrasal-root*))
                  value)
		 (t (mbug "unexpected contents of tense-modal ~a" value)))))
    (let ((new-position (attach-by-splicing ap position contents)))
      (assert new-position)
      ;; Remove tense-modal's current position
      (setf (available-aps *current-phrasal-root*) 
            (delete ap (available-aps *current-phrasal-root*)))
      ;; Figure out what the next aux AP should be and add it
      (push (attachment-point-for-next-aux new-position contents)
	    (available-aps *current-phrasal-root*))
      ;; 
      (push (cons 'tense-marker new-position)
	    (position-table *current-phrasal-root*)))))


(defun attachment-point-for-next-aux (position contents)
  (let ((ap (splicing-attachment-point-named 'next-aux)))
    (set-link ap 'next)
    (case (state-value ':aux-state (state *current-phrasal-root*))
      ((initial unmarked) (cons ap position))
      (prepose-aux 
       (typecase contents
	 (word (change-state ':aux-state 'initial (state *current-phrasal-root*))
	       (cons ap (cdr (assoc 'subject
				    (position-table *current-phrasal-root*)))))
	 (tense-marker (cons ap position))
	 (otherwise
	   (mbug "error--attachment-point-for-next-aux; unexpected contents"))))
      (otherwise
       (mbug "error--attachment-point-for-next-aux; unexpected state")))))


(defun process-negate-accessory ()

; The processing of this accessory is ordered after that of all the other
; accessories that could contribute to the verb group.  We want to splice in
; a [negation] position just after the first non-main element of the
; verb group, so we check the Aux-state to find out which element that is
; in this case.
; 
; When processing the bundle, the State of the clause under construction
; is set to  Preposed-auxiliary, which induces "do-insertion"
; analogously to questions when PSE walks through the surface
; structure -- see the code in Morphology.)

  (let ((tense-marker-slot
	  (cdr (assoc 'tense-marker
		      (position-table *current-phrasal-root*)))))
    
    (multiple-value-bind (position link)
	(if (not tense-marker-slot) ;; i.e. infinitives
	    (let ((verb-slot
		    (cdr
		      (assoc
			'verb
			(position-table *current-phrasal-root*)))))
	      (when (not verb-slot)
		(mbug "The algorithm for placing NEG when there's no ~
                             tense marker is confused."))
	      (values verb-slot 'before))
	    (let* ((next-position-after-TM
		     (next tense-marker-slot))
		   (labels-on-next-position
		     (labels next-position-after-TM)))
	      (cond ((not (typep (contents tense-marker-slot)
				 'tense-marker))
		     
		     ;; "wouldn't"
		     (values tense-marker-slot 'after))
		    
		    ((member (label-named 'subject)
			     labels-on-next-position)
		     (values tense-marker-slot 'after))
		    
		    ((intersection
		       labels-on-next-position
		       (list (label-named 'be+ing)
			     (label-named 'have+en)
			     (label-named 'be+en)))
		     (values next-position-after-TM 'after))
		    
		    (t  ;;needs do insertion
		     (set-state *current-phrasal-root*
				(change-state
				  ':aux-state 'prepose-aux
				  (state *current-phrasal-root*)))
		     (values tense-marker-slot 'after)))))
      
      (let ((position-before (if (eq link 'after)
				 position
				 (previous position)))
	    (position-after  (if (eq link 'after)
				 (next position)
				 position)))
	
	(splice-in position-before
		   position-after
		   (word-for-string "not")
		   (slot-label-named 'negative))))))


(defun process-perfect-accessory ()
  (let* ((ap (splicing-attachment-point-named 'next-aux))
         (position (position-of-ap ap))
	 (contents (word-for-string "have" 'verb)))
    (set-new-slot ap  (label-named 'have+en))
    (let ((new-position (attach-by-splicing ap position contents)))
      (setf (available-aps *current-phrasal-root*)
            (delete ap (available-aps *current-phrasal-root*)))
      (push (attachment-point-for-next-aux new-position contents)
	    (available-aps *current-phrasal-root*))
      (push (cons 'have+en new-position)
	    (position-table *current-phrasal-root*))
      (when (eq (state-value ':aux-state (state *current-phrasal-root*))
	      'prepose-aux)
        (change-state ':aux-state 'initial (state *current-phrasal-root*))))))


(defun process-progressive-accessory ()
  (let* ((ap (splicing-attachment-point-named 'next-aux))
         (position (position-of-ap ap))
	 (contents (word-for-string "be" 'verb)))
    (set-new-slot ap (label-named 'be+ing))
    (let ((new-position (attach-by-splicing ap position contents)))
      (setf (available-aps *current-phrasal-root*)
            (delete ap (available-aps *current-phrasal-root*)))
      (push (attachment-point-for-next-aux new-position contents)
            (available-aps *current-phrasal-root*))
      (push (cons 'be+ing position)
            (position-table *current-phrasal-root*))
      (when (eq (state-value ':aux-state (state *current-phrasal-root*))
                'prepose-aux)
        (change-state ':aux-state 'initial (state *current-phrasal-root*))))))


(defun process-passive-accessory ()
  (let* ((ap (splicing-attachment-point-named 'next-aux))
         (position (position-of-ap ap))
	 (contents (word-for-string "be" 'verb)))
    (set-new-slot ap (label-named 'be+en))
    (let ((new-position (attach-by-splicing ap position contents)))
      (setf (available-aps *current-phrasal-root*)
            (delete ap (available-aps *current-phrasal-root*)))
      (push (attachment-point-for-next-aux new-position contents)
            (available-aps *current-phrasal-root*))
      (push (cons 'be+en position)
            (position-table *current-phrasal-root*))
      (carry-out-passive-transformation)
      (when (eq (state-value ':aux-state (state *current-phrasal-root*))
                'prepose-aux)
        (change-state ':aux-state 'initial (state *current-phrasal-root*))))))




;;;----------------------------------
;;; Accessories involving nouns/NPs
;;;----------------------------------

(defun process-no-accessory (np)
  "Attach a quantifier slot and put 'no' in it"
  (let ((no (find-word "no" 'quantifier)))
    (attach no (attachment-point-named 'quantifier-premod))))

(defun process-number-accessory (np value-of-number)
  (set-state (context-object np)
	     (initialize-state :number (name value-of-number)
			       (state (context-object np)))))

(defun process-person-accessory (np value-of-person)
  (when value-of-person
    (set-state (context-object np)
	       (initialize-state :person (name value-of-person)
				 (state (context-object np))))))

(defun process-proper-name-accessory (np)
  (add-label-to np 'proper-name))

(defun process-determiner-accessory (bundle np determiner-policy)
  (push-debug `(,bundle ,np ,determiner-policy))
  (ecase (name determiner-policy)
    (indefinite-first-mention_definite-subsequent-mentions
     (let ((referent (etypecase bundle
                       (referential (referent bundle)) ;; dtn
                       (specification (underlying-object bundle)))))
       (if (first-mention? referent)
	 (set-determiner-state np 'indefinite)
	 (set-determiner-state np 'definite))))
    (always-definite 
     (set-determiner-state np 'definite))
    (no-determiner
     ;;e.g. for proper names, indefinites
     (set-determiner-state np 'no-determiner))
    (anonymous-individual
     (set-determiner-state np 'indefinite))
    (known-individual 
     (set-determiner-state np 'definite))
    (kind
     (set-determiner-state np 'indefinite))))


;;;--------------
;;; conjunction 
;;;--------------

(defun process-conjunction-accessory (conjunction node)
  (typecase conjunction
    (symbol
	(add-label-to (last-constituent node)
		      (label-named conjunction)))
    (label (add-label-to (last-constituent node)
			 conjunction))
    (cons  ;;assumes if its a list, there are only two
      ;;this is for pairs:  either/or both/and
      (let ((conj1 (car conjunction))
	    (conj2 (cadr conjunction)))
	(add-label-to (first-constituent node) conj1)
	(add-label-to (last-constituent node) conj2)))
    ))





(defun return-position-with-contents (value)
  (block found
    (dolist (item (position-table *current-phrasal-root*))
      (let ((P (cdr item)))
	(when (and (slotp P) (eq value (contents P)))
	  (return-from found P))))
    (return-from found nil)))


(defun add-label-to (position label-name)
  (let ((label (if (labelp label-name)
		   label-name
		   (label-named label-name))))
    (when (not (member label (labels position)))
      (set-labels position (nconc (labels position)
				  (list label))))
      ))


;;;-------
;;;  VPs
;;;-------

(defun process-vp-accessories (B)
  (let ((acc (get-accessory-value :aspect B)))
    (when acc
      (process-aspect-accessory acc))))

(defun process-aspect-accessory (aspect)
  (case (name aspect)
    (gerund
      (change-state ':aux-state 'present-participle
		    (state *current-phrasal-root*)))
    (past-participle
      (change-state ':aux-state 'past-participle
		    (state *current-phrasal-root*)))
    ))

