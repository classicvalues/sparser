;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:(SPARSER COMMON-LISP) -*-
;;; Copyright (c) 2022 SIFT LLC. All Rights Reserved
;;;
;;;    File: "loader"
;;;  Module: "grammar/model/sl/score-stats
;;; version: June 2022

;;; started 9/2020 to gather tests and their metrics for reading
;;; articles for the SCORE project and other articles with statistics,
;;; especially in the behavioral sciences.

(in-package :sparser)

(gload "score-stats;statistical-variables")
(gload "score-stats;statistical-measurements")
(gload "score-stats;statistical-tests")

(gload "score-stats;experiment-language")

;; explicitly loaded very late by load-the-grammar
;; (gload "score-stats;synonym-grammar")
