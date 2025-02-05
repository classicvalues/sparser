;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1995,2013,2017 David D. McDonald  -- all rights reserved
;;;
;;;     File:  "copula patterns"
;;;   Module:  "grammar;rules:tree-families:"
;;;  version:  August 2017

;; formed 10/18/95. Cleaned up a bit 10/9/13.
;; 8/14/17Referring to 'be' in complement clause is all of a sudden weirding out
;; the decode-etf-rule-case call to form-category?

(in-package :sparser)


;; see QGL&S 2.4  They call this pattern a subject plus a subject-complement

#+ignore(define-category be :instantiates self)
  ;; this file (all etf files) are loaded before the files of
  ;; syntactic rules where the full def. of 'be' will be given

(define-exploded-tree-family   thing-is-description
  :description "A clause based on the verb 'to be'. 
      A property is being ascribed to a (usually concrete) individual: \"The sky is blue\". 
      Semantically, the result is to put the individual into a relationship 
      with the property or description."
  :binding-parameters ( result  individual  description )
  :labels ( s  vp copular-verb np/subject  complement )
  :cases
     ((:subject (s (np/subject vp)
                 :head right-edge
                 :binds (individual left-edge)))

      (:complement-of-be  (vp (copular-verb complement)
                           :instantiate-individual  result
                           :head left-edge
                           :binds (description right-edge)))

   #| (:copula-inversion/vp  (be- (be np/subject)
                              :instantiate-individual  ????
                              :binds (individual right-edge)))
 ?? What do you instantiate? -- has to be something or else we'd lose
    the opportunity to bind the complement.  But we won't know what
    the resulting type is until we see the subject (..though in terms
    of the left-to-right scan we do know it -- maybe this is a good
    reason to organize the scan as subj+verb rather than the usual
    right recursion pattern)

      (:copula-inversion )  |#

      ))

