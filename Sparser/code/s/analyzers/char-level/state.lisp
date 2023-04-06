;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1990,1991 Content Technologies Inc.
;;; copyright (c) 1991-1993,2022 David D. McDonald  -- all rights reserved
;;; 
;;;     File:  "state"
;;;   Module:  analyzers/char-level/
;;;  Version:  January 2022

;; 1.1  (2/7  v1.8.1)  Added *embedded-strings-cib* for the use of
;;      Tokens-in-string/no-whitespace
;; 1.2  (11/29 v2.1) Pulled the type restriction from the defstruct
;; 1.3  (1/13 v2.2) Noted that the arrays of characters need a different
;;      type specification when running under ansii lisp
;; 2.0 (9/25/92 v2.3) redone for new tokenizer
;; 2.1 (2/14/93) put in the change from 'string-character to character
;;      to move to MCL2.0
;; 2.2 (5/12/93) commented out DCB because it was so far out of date

(in-package :sparser)

;;;---------
;;; globals
;;;---------

(defvar *index-of-next-character* -1
  "A number that indicates which cell of the *character-buffer-in-use*
   the tokenizer should take the next character from. Incremented
   each time it is used, hence it's initialization to minus one.")

(defvar *length-of-character-input-buffer*)
(unless (and (boundp '*length-of-character-input-buffer*)
             (numberp *length-of-character-input-buffer*))
  (defparameter *length-of-character-input-buffer*  200000
    ;; 200,000 characters
    ;; formerly 1000 -- Has to be large to read the articles in
    ;; CALLISTO -- Rusty
    "A performance variable.  Should be adjusted to tradeoff between
     the size of the stored image and the overhead of sucessively
     opening the source to fill it."))

(defparameter *usable-amount-of-character-buffer*
              (1- *length-of-character-input-buffer*)
  "Reflects the fact that some of the buffer is taken up by control
   characters that signal when to do a refill or when the source
   has ended")


(defvar *original-string* nil
  "Used only when the input is a string that is longer than the
   character buffer.  Keeps the pointer that is used as the buffer
   is refilled.")


;;;--------------------------
;;; creating the two buffers
;;;--------------------------

(defparameter *first-character-input-buffer*
  (make-array *length-of-character-input-buffer*
              :element-type 'character
              ))

(defparameter *second-character-input-buffer*
  (make-array *length-of-character-input-buffer*
              :element-type 'character
              ))


;;;--------------------------------------------------------------
;;; put buffer-change characters in the last cell of each buffer
;;;--------------------------------------------------------------

(setf (elt *first-character-input-buffer*
           (1- *length-of-character-input-buffer*))
      #\^D)
(setf (elt *second-character-input-buffer*
           (1- *length-of-character-input-buffer*))
      #\^D)

#| The source-start #\^A is inserted when we're establishing the
character source, e.g. by establish-character-source/string which
fills from position 1 onwards and then sets position 0 to
the start character.  The #\^B for the end of the source is
added at the same time. |#


;;;-------------------------------------------------
;;; propagate impact of having truncated the source
;;;-------------------------------------------------

(defvar *the-source-was-truncated* nil
  "If set it means that the prescan operation has walked to
 the end of its source character buffer and we have had to truncate the source.")

(defun announce-truncated-source (source-index)
  "Invoked from scan-and-swap-character-buffer when it scans the ^D.
   The dual buffer setup that ^D was designed to manage was done in
   decades ago when machine resources were expensive. In the modern day
   we can make the length of the character buffer much larger and
   suffer no ill effects. In particular starting in 2019 we put the
   second buffer into use as the sink for prescanning the characters
   in the array and doing things like expanding HTML escapes and
   canonicalizing the number of newlines between paragraphs. Returning
   to a rotating buffer design would require non-trivial refactoring
   that needs a good motivation. Even with the buffers at their
   present length (200k characters) we can encounter larger file
   sources so we need to set a limit. 
   At 200k characters we will probably have recycled the chart (presently
   just 40k positions) and the edges (100k), which makes it problematic
   to pull information out. This flag is to signal that some things
   won't work as expected"
  (declare (special *next-chart-position-to-scan*
                    *open-stream-of-source-characters*))
  (let ((stream *open-stream-of-source-characters*))
    (format t "~&--- Cannot process this file~
               ~% ~a~
               ~% because it is longer than our buffer size of ~a characters"
              stream (insert-commas-into-number-string source-index))
    (close-character-source-file)
    (setq *the-source-was-truncated* t)))


;;;------------------------------
;;; keeping track of the buffers
;;;------------------------------

(defparameter *character-buffer-in-use* nil
  "The buffer characters are presently being drawn out of")

(defparameter *the-next-character-buffer* nil
  "Once the buffer in use is filled, we will switch to using
   this buffer.")

(defvar *buffers-in-transition* nil
  "A flag that indicates that we have just switched from one
   buffer to the other.  Needed for tokens that span both buffers
   whose indicies need special handling.")

(defvar *length-accumulated-from-prior-buffers* 0
  "As the analyzer procedes through the characters of an article,
   it will typically load and scan several buffer-length of characters.
   The primary index into the characters is the buffer-specific index.
   This accumulator must be added to that index to get the actual
   character-offset into the article of a given character.
     This accumulator is initialized when the buffers are initialized,
   and added to in Next-char after it has the buffer refilled.")

;;;------------
;;;  display
;;;------------

(defun cur-string (&key (prev-chars 40) (next-chars 20))
  "Return a short, localized subsequence of the current character buffer."
  (if (or (not *character-buffer-in-use*) (minusp *index-of-next-character*))
    ""
    (let ((source-start (1+ (or (search (word-pname *source-start*)
                                        *character-buffer-in-use*
                                        :end2 *index-of-next-character*
                                        :from-end t)
                                -1)))
          (source-end (or (search (word-pname *end-of-source*)
                                  *character-buffer-in-use*
                                  :start2 *index-of-next-character*)
                          (length *character-buffer-in-use*)))
          (window-start (- *index-of-next-character* prev-chars))
          (window-end (+ *index-of-next-character* next-chars)))
      (concatenate 'string
                   (if (< source-start window-start) "..." "")
                   (subseq *character-buffer-in-use*
                           (max source-start window-start)
                           (min source-end window-end))
                   (if (> source-end window-end) "..." "")))))

#| these are out of date

(defun print-object/character-input-buffer (obj stream depth)
  (declare (ignore depth))
  (write-string "#<character-buffer " stream)
  (princ (cib-buffer-name obj) stream)
  (write-string " " stream)
  (let ((source (cib-source obj)))
    (typecase source
      (string
       (if (> 10 (length source))
         (princ source stream)
         (princ (subseq (cib-source obj) 0 10) stream))
       (write-string "...>" stream))
      (otherwise
       (princ (cib-source obj) stream)))
    (write-string ">" stream)))


(defun dcb  ;; "Display-input-buffer"
       (&optional (s *standard-output*))
  (let ((b1 *first-character-input-buffer*)
        (b2 *second-character-input-buffer*))

    (format s "~%Character-input-buffers:~
               ~%         buffer in use: ~A~
               ~%           next buffer: ~A~
               ~% buffers in transition? ~A~
               ~%First Buffer:~
               ~%       next character: ~A~
               ~%   position in source: ~A~
               ~% number of characters: ~A~
               ~%   terminates source?: ~A~
               ~%Second Buffer:~
               ~%       next character: ~A~
               ~%   position in source: ~A~
               ~% number of characters: ~A~
               ~%   terminates source?: ~A"
            *character-buffer-in-use*
            *the-next-character-buffer*
            *buffers-in-transition*
            (cib-position-of-next-unread-character b1)
            (cib-position-of-buffer-within-source b1)
            (cib-number-of-characters-in-buffer b1)
            (cib-terminates-source? b1)
            (cib-position-of-next-unread-character b2)
            (cib-position-of-buffer-within-source b2)
            (cib-number-of-characters-in-buffer b2)
            (cib-terminates-source? b2))))  |#

