;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:(SPARSER LISP) -*-
;;; copyright (c) 1993-1997,2012-2021  David D. McDonald  -- all rights reserved
;;;
;;;     File:  "driver"
;;;   Module:  "model;core:names:fsa:"
;;;  Version:  July 2021

;; initiated 5/15/93 v2.3, added traces 5/26
;; 0.1 (12/9) Added pre-emptive state variable
;; 0.2 (12/17) added more globals to allow communication between distant
;;      subroutines and driver
;;     (4/4/94) added global var to keep track of the starting position
;;     (7/18) added parameter to control pre-emptive state var.
;; 0.3 (7/21) added status keyword for when PNF is preempted
;; 0.4 (9/28) put in a parameterized toplevel to the driver and added a
;;      scan-only routine
;;     (2/2/95) added a small variation on that scan-only routine
;; 0.5 (2/13) added checks for flags set during the scan for the dm&p cases
;;     (8/17/97) moved *ignore-capitalization* up to [drivers;inits:sessions:globals1]
;; 0.6 (11/1/12) In pnf/scan-classify-record added call to sort out the bracketing
;;     beause the initial company is swallowing any following under-modeled
;;     verb in DM&P mode.
;; 0.7 (2/3/13) Changed pnf/scan-classify-record to ignore function words
;;     at sentence starts.
;; 0.8 (7/25/13) Added *arabic-names*

(in-package :sparser)

;;;---------
;;; globals
;;;---------

(defparameter *debug-pnf* nil
  "Flag used to control whether we go into a breakpoint on oddities
   or alternatively take some heuristic default")


(defvar *capitalization-is-uninformative* nil
  "Used as a flag inside headlines and such. Set by various
   header-field actions. Initialzed by Initialize-section-state.")

(defparameter *cap-seq-edge-data-routine* 'cap-seq-no-referent
  "The function used by Make-edge-over-capitalized-sequence to compute
   the category, form, referent, etc. of the edge formed when the
   PNF routine doesn't use the full bore classification routines.")

(defvar *pnf-has-control* nil
  "A flag used to communicate to embedded parsing and action
   routines that should behave differently if we're doing PNF or not.")

(defvar *pnf-end-of-span* nil
  "Held by the driver to obviate the need for classifying routines
   to have to return the end-pos. Set up as a global so that those
   same routines can communicate changes to it.")

(defvar *pnf-scan-starts-here* nil
  "set by PNF before it begins its scan and referenced within the
   classifier and such as part of making subdivisions of names compounded
   out of other names.")

(defvar *hyphen-seen* nil
  "Set in checkout-hyphen-for-capseq to the position of the hyphen.
   Read in examine")

(defparameter *pnf-scan-respects-segment-boundaries* nil
  "If so, the scan will lookahead for anticipated cases but otherwise
   stop when a segment ']' boundary is seen.  Bound by the PNF routine.")

(defparameter *pnf-scan-ignores-the-possibility-of-initials* nil
  "Read in Checkout-punctuation-for-capseq. Bound by the PNF routine.")


(defparameter *arabic-names* nil
  "Read in checkout-single-quote-for-capseq to permit any lowercase
   continuation after an appostrophe.")

(defvar *text-span-of-pnf-analysis* nil
  "When we have delimited the start and end positions, this will be
   dynamically bound to the text in that region to help debugging")


;;;----------------------
;;; parameterized driver
;;;----------------------

(defun establish-pnf-routine (keyword &optional fn-name)
  (setq *pnf-routine* keyword))


#| (trace-pnf)
(setq *break-before-examining* t ;; Before examine-capitalized-sequence starts
      *break-on-new-categories-in-cap-seq* t ;; bottom of its first flet fn.
      *break-before-creating-name* t) |#


(defun pnf (starting-position &optional continue-pos)
  "Invoked from word-level-fsa-sweep when pnf is loaded,
   *pnf-routine* has been given a value, and the
   word that the sweep has reached is capitalized. "
  (unless *pnf-routine*
    (error "no value supplied for the PNF routine"))
  (ecase *pnf-routine*
    (:scan-classify-record
     (pnf/scan-classify-record starting-position continue-pos))
    (:scan/ignore-boundaries
     (pnf/scan/ignore-boundaries starting-position))
    (:scan/ignore-boundaries/initials-ok
     (pnf/scan/ignore-boundaries/initials-ok starting-position))))


;;;-----------------
;;; standard driver
;;;-----------------

; (establish-pnf-routine :scan-classify-record)

(defun pnf/scan-classify-record (starting-position &optional continue-pos)
  "The default version of the Proper Name Facility.
 There is a capitalized word at the starting-position. That's why we were
 called. We check for some cases that typically mean the capitalization is not
 signalling a name and then return nil signalling to the word-level-fsa-sweep
 that we've failed. 
   Then we call cap-seq-continues-from-here? to locate where the capitalized
 sequence ends (*pnf-end-of-span*). This scan only considers capitalization,
 punctuation, and a small list of specfic words.

   Classify-and-record-name organizes all the heavy lifting
 and either returns an edge or returns nil if it aborted from some reason.
 If we got an edge we return the position where the span ended, i.e. the position
 just after the final capitalized word in the span.

    When there is more than one word in the span that has been delimited,
 c&r-multi-word-span ('classify and record) orchestrates what happens.
 It runs pfwpnf ('parse from within pnf') to check for word FSAs and do
 install-terminal-edges. At that point a tailored mini-parser that is only
 permitted to use semantic rules), parse-between-boundaries, runs.
"
  (declare (special *show-note-candidates*))
  (tr :initiating-pnf starting-position)
  (set-status :pnf-checked starting-position)
  (cond
   (*capitalization-is-uninformative*
    (tr :pnf/preempted)
    (set-status :pnf-preempted starting-position)
    nil )
   ((and (function-word? (pos-terminal starting-position))
         (could-be-the-start-of-a-sentence starting-position))
    (tr :pnf/fn-word-at-sentence-start (pos-terminal starting-position))
    (set-status :pnf-preempted starting-position)
    nil )
   (t
    (set-status :pnf-checked
                starting-position)
    (let ((*pnf-has-control* t)
          (*pnf-scan-starts-here* starting-position))

      (let* ((*pnf-end-of-span*
              (cap-seq-continues-from-here?
               (or continue-pos
                   (chart-position-after starting-position))))
             (*text-span-of-pnf-analysis*
              (extract-characters-between-positions *pnf-scan-starts-here*
                                                    *pnf-end-of-span*)))
        (declare (special *text-span-of-pnf-analysis*))

        (tr :pnf/sequence-ended *pnf-end-of-span*)

        (let ((edge
               (classify-and-record-name starting-position
                                         *pnf-end-of-span*)))
          (if edge
            (tr :pnf/classification edge *pnf-end-of-span*)
            (tr :pnf/aborted-during-classification))

          (when edge
            (sort-out-name-bracketing-state
             starting-position *pnf-end-of-span* edge)
            (when *show-note-candidates*
              (format t "~&PNF: ~a~%" edge))
            (note? edge))

          (if edge
            *pnf-end-of-span*
            nil)))))))



;;;---------------------------------------
;;; drivers that don't classify or record
;;;---------------------------------------

(defun pnf/scan/ignore-boundaries (starting-position)
  ;; designed for dm&p where there are lots of names but they aren't
  ;; the names of people or companies
  (declare (special *pos-possible-next-letter*))
  (tr :initiating-pnf starting-position)
  (set-status :pnf-checked starting-position)
  (if *capitalization-is-uninformative*
    (then (tr :pnf/preempted)
          (setf (pos-assessed? starting-position) :pnf-preempted)
          nil )

    (let ((*pnf-has-control* t)
          (*pnf-scan-starts-here* starting-position)
          (*pnf-scan-respects-segment-boundaries* nil)
          (*pnf-scan-ignores-the-possibility-of-initials* t))

      (let ((*pnf-end-of-span*
             (cap-seq-continues-from-here? (chart-position-after
                                            starting-position))))
        (tr :pnf/sequence-ended *PNF-end-of-span*)

        ;; One of the ways we can come out of the scan is via
        ;; a Throw from some routine that says explicitly that
        ;; the scan should be ended. (The Catch is in Cap-seq-
        ;; continues-from-here?)  Sometimes that routine initiating
        ;; the Throw will also set up some state reflecting its
        ;; knowledge of the situation. We check for that state
        ;; here and do what it indicates.
        (cond
         (*pos-possible-next-letter*
          *pnf-end-of-span*)
         (t  ;; standard continuation
          (adjudicate-possible-sentence-start-and-make-Cap-seq-edge
           starting-position *pnf-end-of-span*)))))))

;(establish-pnf-routine :scan/ignore-boundaries)



(defun pnf/scan/ignore-boundaries/initials-ok (starting-position)
  ;; Identical to the driver above except for the initials flag
  (declare (special *pos-possible-next-letter*))
  (tr :initiating-pnf starting-position)
  (set-status :pnf-checked starting-position)
  (if *capitalization-is-uninformative*
    (then (tr :pnf/preempted)
          (setf (pos-assessed? starting-position) :pnf-preempted)
          nil )

    (let ((*pnf-has-control* t)
          (*pnf-scan-starts-here* starting-position)
          (*pnf-scan-respects-segment-boundaries* nil)
          (*pnf-scan-ignores-the-possibility-of-initials* nil))

      (let ((*pnf-end-of-span*
             (cap-seq-continues-from-here? (chart-position-after
                                            starting-position))))
        (tr :pnf/sequence-ended *PNF-end-of-span*)

        (cond
         (*pos-possible-next-letter*
          *pnf-end-of-span*)
         (t  ;; standard continuation
          (adjudicate-possible-sentence-start-and-make-Cap-seq-edge
           starting-position *PNF-end-of-span*)))))))

#|(establish-pnf-routine :scan/ignore-boundaries/initials-ok
                         'pnf/scan/ignore-boundaries/initials-ok)  |#







;;;------------------------------------
;;; dispatch within Word-actions check
;;;------------------------------------

#| N.b. this routine is irrelevant if the scan network is using the 'send
   everything through PNF' model of operation.  In that case the switch
   setting should be (establish-version-of-capitalization-dispatch :no-op)
   or else PNF will be called twice on every unknown word.  |#

(defun word-actions-dispatch/check-for-capitalized (capitalization
                                                    word
                                                    position)
  ;; This check is made for all unknown words.
  ;; If other dispatches should be made as well (e.g. if scheme for
  ;; doing digits moved here rather than being done over edges)
  ;; then this routine has to be extended.

  (declare (ignore word))
  (case capitalization
    (:lower-case nil)
    (:punctuation nil)
    (:digits nil)
    (otherwise (pnf position))))

