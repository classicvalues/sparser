;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:(SPARSER COMMON-LISP) -*-
;;; Copyright (c) 2007 BBNT Solutions LLC. All Rights Reserved
;;; copyright (c) 2013  David D. McDonald  -- all rights reserved
;;;
;;;      File:   "pathogen-type"
;;;    Module:   "sl;disease:"
;;;   version:   August 2013

;; Category to represent types of disease vectors: virus, bacteria, prion, etc.
;; this category can be analogous to pronouns
;; when a pathogen-type is mentioned, it is picking out a named pathogen
;; from set of salient ones


(in-package :sparser)

;;;------------
;;; the object
;;;------------

(define-category pathogen-type
  :specializes pathogen
  :instantiates self
  :binds ((name :primitive word))
  :index (:permanent :key name)
  :realization (:common-noun name))


;;;-----------
;;; citations
;;;-----------

;;"the deadly avian virus"


;;;------
;;; form
;;;------

(defun define-pathogen-type (string)
  (let ((name (define-or-find-individual
                  'pathogen-type :name string)))
        name))

