;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 2017-2019 David D. McDonald  -- all rights reserved
;;;
;;;      File:   "qualities"
;;;    Module:   "model;dossiers:"
;;;   Version:   September 2019

;; Moved out of the definition files 1/11/17

(in-package :sparser)

;;--- color
(define-color "black") ;; all :+ by default
(define-color "white")

(define-color "blue")
(define-color "brown")
(define-color "green")
(define-color "orange")
(define-color "pink")
(define-color "purple")
(define-color "red")
(define-color "yellow")
(define-color "violet")
#|The current 24-count Crayola box contains
 red, yellow, blue, brown, orange, green, 
violet, black, carnation pink, yellow orange, 
blue green, red violet, red orange, yellow green, 
blue violet, white, violet red, dandelion, 
cerulean, apricot, scarlet, green yellow, 
indigo and gray.Mar 28, 2017
|#

;;--- size
(define-size "big" :dir :+)
(define-size "little" :dir :-)
;; DAVID -- (define-size "little to no" ...) caused an error -- WHY
(adj "little to no" :specializes size-value) ;; little to no evidence was found

(define-size "large" :dir :+)
(define-size "small" :dir :-)

;;--- height
(define-height "short" :dir :-)
(define-height "tall" :dir :+)

(define-amount "high" :dir :+) ;; not quite the same thing
(define-amount "low" :dir :-)
;;  separable task of coersing to a state

;;--- width
(define-width "narrow" :dir :-)
(define-width "wide" :dir :+)

;;--- length
(define-length "long" :dir :+)
;;(define-length "short" :dir :-) duplicate w/ height?, need neutral

;;--- rate of change
(define-rate-of-change "fast" :dir :+)
(define-rate-of-change "slow" :dir :-)

;;--- quality (called goodness to avoid clash)
(define-goodness "good" :dir :+  :er "better" :est "best")
(define-goodness "great" :dir :+ :er "greater" :est "greatest") ; default more doubles the 't'
(define-goodness "bad" :dir :- :er "worse" :est "worst")

(def-synonym good (:adj "well")) ; doubling the adj field with "good" would be more to the point

#|
------- "more"
 more broadly
a more definitive analysis of
 more lung tumors than 
is more sensitive to 
is more effective than 
may be somewhat more resistant to
 a more physiologically relevant cell type
(load-test 746
 "Because a combination of rapamycin and BAY43-9006
 is more effective at inhibiting melanoma cell proliferation
 than either drug alone, ...)
were more common in
was suppressed more effectively by
|#
