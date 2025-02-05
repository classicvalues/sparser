;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1991-1996,2013,2016-2022  David D. McDonald  -- all rights reserved
;;; extensions copyright (c) 2009 BBNT Solutions LLC. All Rights Reserved
;;; 
;;;     File:  "articles"
;;;   Module:  "drivers;inits:"
;;;  Version:  January 2022

;; 1.1  (3/28/91 v1.8.1)  Added Clear-individuals, and improved the
;;      conditionalization according to the load-time switches
;; 1.2  (7/11 v1.8.5)  Added Clear-traversal-state and merged the two
;;      when's on *model* into one if.
;; 1.3  (10/8 v2.0)  Removed the possibility that *model* could be Nil
;; 1.4  (11/12 v2.0.1)  Put back in the equivalent -- a check that the
;;      grammar has been loaded ///needs some flags as well.
;; 1.5  (5/9/92 v2.2) Added clearing the stack of pending left openers
;; 1.6  (6/19) Added initializing the context variables
;; 1.7  (7/14 v2.3) Switched fromm anaphor table to Discourse-history
;; 1.8  (9/2) commented out the salient-objects, since that code isn't
;;        being loaded at this point with the new category stuff
;; 2.9  (12/28) pulled a reference to the old indexing scheme for names
;; 2.10 (11/12/93) added clearing the display window
;; 2.11 (12/8) switched to a generic routine for initializing sections.
;; 2.12 (12/15) introduced a mechanism for open-ended initializations
;; 2.13 (5/2/94) tweeked routine so that those initializations would be
;;       seen even if the grammar flag was down (e.g. for bbn)
;; 2.14 (8/8) reordered Reap-individuals and Initialize-discourse-history
;;      (5/13/95) promulgated a fn renaming.
;;      (1/9/96) added check for an interrupted embedded scan.
;; 2.15 (7/23/09) Added clear-debug.
;; 2.16 (2/11/13) Broke out the 'real' per article initialization so it
;;       can be called by itself. (2/18/13) broke out the individual and 
;;       history cleaner for the same reason. Gating that on the global
;;       bound in do-document-as-stream-of-files. 
;; 2.17 (3/14/13) Added section initialization and article creation,

(in-package :sparser)


;;;-------------
;;; accumulator
;;;-------------

(defparameter *per-article-initializations* nil
  "Accumulates forms to be passed to eval during
   Per-article-initializations")


;;;--------
;;; driver
;;;--------

(defun per-article-initializations ()
  "Invoked from analysis-core before any analysis starts provided
   that the *initialize-with-each-unit-of-analysis* flag is up.
   This will clear/reinitialize every article-specific property,
   except as overridden by other parameters consulted here."
  (declare (special *saved-toplevel-parsing-protocol*
                    *make-fresh-articles*))

  (when *saved-toplevel-parsing-protocol*
    ;; we could have error'd out before this was reset
    (resume-old-parsing-protocol))

  (clear-debug) ;; zero's the stack

  (when *load-the-grammar*
 
    (clear-traversal-state)
    (clear-stack-of-pending-left-openers)

    ;; This is an ad-hoc system setup for wsj job-events
    ;; it has to be redone -- code loads w/ Who's News
    ;(when *track-salient-objects*
    ; (initialize-salient-object-record))

    #+mcl 
    (when *display-text-to-special-window*
      (clear-special-text-display-window))
    
    (when *recognize-sections-within-articles*
      (when *make-fresh-articles*
        (strip-unnecessary-article-parts (article))) ; the previous one
      (initialize-document-element-resources)
      (begin-new-article))
    
    (when *context-variables* ; read in begin-new-article
      (clear-context-variables)
      (initialize-context-variables))
   
    (when *include-model-facilities*
      (unless *accumulate-content-across-documents*
        ;; See description on this variable, but note
        ;; that is also set to t when reading documents
        ;; in the paragraph case of read-from-document.
        ;; In this case there is a special clean-out
        ;; call at article start.
        (clean-out-history-and-temp-objects))))

  (run-real-per-article-initializations))


;;;----------------------------------------------------
;;; per-sentence initializations for successive-sweeps
;;;----------------------------------------------------
#| When the kind of chart parsing is successive-sweeps,
 we making a series of passes over the portion of the
 input / chart that is delimited by a, frequently predefined,
 sentence. Certain state variables don't make sense unless
 they are appreciated within the sentence that they are
set in. This initialization manages them.|#

(defun sentence-level-initializations ()
  "Called in scan-terminals-loop before it starts to
   scan any terminals."
  (declare (special *localization-interesting-heads-in-sentence*))
  (when *localization-interesting-heads-in-sentence*
    (reset-localization-interesting-heads-in-sentence))
  (initialize-note-edge-cache)
  (clear-traversal-state))


;;;--------------------------------------
;;; Clearing the memory of past analyses
;;;--------------------------------------

(defun clean-out-history-and-temp-objects ()
  ;; the temp. individuals reap is ordered before the initialization
  ;; because it uses the discourse history to tell it
  ;; what to reap
  (reclaim-temporary-individuals)
  (zero-bound-in-fields)
  (clean-out-note-data)
  (initialize-discourse-history))


;;;----------------------------------------
;;; managing *per-article-initializations*
;;;----------------------------------------

(defun run-real-per-article-initializations ()
  (when *per-article-initializations*
    (dolist (form *per-article-initializations*)
      (eval form))))

(defun define-per-run-init-form (s-exp)
  (unless (listp s-exp)
    (error "A per-run-init-form must be a list.~
            ~%  Your argument: ~A~
            ~%  is a ~A" s-exp (type-of s-exp)))

  (pushnew s-exp *per-article-initializations* :test #'equal)
  (length *per-article-initializations*))


(defun remove-per-run-init-form (s-exp)
  (unless (listp s-exp)
    (error "A per-run-init-form must be a list.~
            ~%  Your argument: ~A~
            ~%  is a ~A" s-exp (type-of s-exp)))
  (let ((initialization-forms *per-article-initializations*))
    (if (member s-exp initialization-forms :test #'equal)
      (then
        (setq *per-article-initializations*
              (delete s-exp initialization-forms
                      :test #'equal))
        (1- (length initialization-forms)))
      (else
        (format  t  "The form ~A~
                     ~%  is not presently included in the ~
                     initialization forms" s-exp)
        nil ))))

(defun list-per-run-init-forms ()
  (pl *per-article-initializations* t))

