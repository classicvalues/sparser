;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1990-1996,2010-2014,2017-2023  David D. McDonald  -- all rights reserved
;;; extensions copyright (c) 2010 BBNT Solutions LLC. All Rights Reserved
;;; 
;;;     File:  "frequency"
;;;   Module:  "rules;words:"
;;;  Version:  October 2023

;; initiated 10/90
;; 3/21/92 Added capitalization information to the dummy words
;; (1/11/94 v2.3) modernized it all
;; 0.1 (6/12) switch'ified the runtime word-checking routine.
;; 0.2 (2/27/95) cleaned up loose ends.
;;     (6/26/96) moved from [analyzers;doc:] to [grammar;rules:words:]
;; 0.3 (6/9/10) Hacking *current-article* so we can to tf/idf analyses
;; 0.4 (6/19/10) Folding in Porter Stemmer. 6/30 tweaking that and the
;;     printers. 7/15/10 implementing tracking freq in different documents.
;;     7/23-25 folding in #<document> object. Refining ...8/16.
;;     7/28/11 Abstracted out def-word to its own file. 3/31/12 fixed fn call.
;;     Through August, September 2012 adding documentation, refining
;;     the code overall. 10/24/13 Started stubbing a document-set driver.
;; 0.5 (10/28/13) Fanout from the make-over of the document classes.
;;     (2/3/14) Some further change required redoing the scope of the
;;     call to stem in wf-classification/ignore-caps
;;     (4/9/14) Added back the document class.

(in-package :sparser)

;;;------------
;;; parameters
;;;------------

(unless (boundp '*stem-words-for-frequency-counts*)
  (defparameter *stem-words-for-frequency-counts* t
    "If not nil, we apply the stemmer defined in /rules/tree-families/
     morphology.lisp to the raw word to determine what we count.
     Gives the best results if *comlex-word-list-loaded* is true."))

(unless (boundp '*include-function-words-in-frequency-counts*)
  (defparameter *include-function-words-in-frequency-counts* nil
    "All known words that have :function-word on their plist are
     usually lumped together under the pseudo-word that is bound
     to *function-word* below. Otherwise they will dominate any
     frequency count."))

(unless (boundp '*include-punctuation-in-frequency-counts*)
  (defparameter *include-punctuation-in-frequency-counts* nil
    "Any word at a position whose capitalization is flagged as
     :punctuation will usually be lumped into the pseud-word
     *punctuation-word*"))

(defparameter *show-word-freq-collection* nil
  "Turns on print operations while the words are being collected")

;;;-----------------
;;; state variables
;;;-----------------

(defvar *words-in-run* 0
  "Bumped with the recording of each word.  Intended to accumulate
   across multiple articles.")

(defvar *word-types* 0
  "Bumped with the recording of each NEW word.")

(defvar *word-types-at-start-of-article* 0
  "Keeps track of how many new words appear in successive articles
   when running over document streams")

(defvar *function-words-seen-in-run* nil
  "When we're aggregating function words, this records which ones were seen.")

(defvar *punctuation-seen-in-run* nil
  "When we're aggregating punctuation, this records what were seen.")

(defparameter *word-frequency-classification* nil
  "Set by Establish-word-frequency-classification. Names the 
   pattern of categories that the words will be sorted into.")

(defparameter *word-count-buckets* nil
  "An alist that reflect a sorting of the word-frequency
   hashtable's data by count.  The first element in each item
   is the frequency, the second is the word count at that
   frequency, and the rest is the list of words.")

(defparameter *word-count-buckets-most-freq-highest* nil
  "The same list ordered from most frequent word to least.")

(defvar *sorted-word-entries* nil
  "Used by setup-word-frequency-data to hold what it says")

;;;----------------
;;; initialization
;;;----------------

(defun initialize-word-frequency-data ()
  (setq *words-in-run* 0
        *word-types* 0
        *word-types-at-start-of-article* 0
        *sorted-word-entries* nil
        *word-count-buckets* nil
        *word-count-buckets-most-freq-highest* nil
	*function-words-seen-in-run* nil
	*punctuation-seen-in-run* nil))

;; N.b. reset/over-all will zero the frequency table and lose
;; all the information about word counts over all and in any
;; document


;;;------------------------------------
;;; the table for "over all" frequency
;;;------------------------------------

(defparameter *word-frequency-table*
              (make-hash-table :test #'eq
                               :size 1000
                               :rehash-size 500)
  "Maps from words to s-expression 'entries' that record the counts
 of the word overall (which accumulates across all runs) and in
 particular documents.")

#| An entry is a list whose car is the count, followed by
 an alist of (<article> . <per-article-count>).  Word objects
 are linked to their entries via the table *word-frequence-table*
 Note that aggregate classes such as numbers are implemented by
 'dummy' words so we're always associating counts with the same
 kind of object.
|#

(defmethod frequency-table-entry ((word word))
  (gethash word *word-frequency-table*
           :no-entry))  ;; the value returned if the word isn't in the table

(defmethod frequency-table-entry ((word polyword))
  (gethash word *word-frequency-table*
           :no-entry))  ;; the value returned if the word isn't in the table

(defmethod frequency-table-entry ((s symbol))
  (let ((word (word-named (string-downcase (symbol-name s)))))
    (frequency-table-entry word)))


(defun reset/over-all ()
  "Forget all of the recorded frequency data. This makes
   sense if there's a big shift in corpus such that you don't
   think the overall counts are meaningful any more, or 
   if there's a big shift in what's being counted."
  (clrhash *word-frequency-table*))

(defun frequency-table-to-list-of-symbols ()
  "Walk through the frequency table to collect all the words,
   pick out their symbols, and return them as an alphabetized
   list."
  (let* ((words 
	  (loop for key being the hash-key in *word-frequency-table*
	     collect key))
	 (symbols (mapcar #'(lambda (w)
			      (intern (word-pname w)))
			  words)))
    (sort symbols #'alphabetize)))


(defmethod total-count ((w word))
  "Returns the total number of times the word has been "
  (let ((entry (frequency-table-entry w)))
    (if (eq entry :no-entry)
      0
      (car entry))))

(defun number-of-words-counted ()
  "All entries in all documents in the set that has been scanned"
  (hash-table-count *word-frequency-table*))


;;;-----------------------------
;;; driver - hooks into Sparser
;;;-----------------------------

#| Note that per-document variables like *words-in-run*
 need to be harvested and save off between documents if they
 are going to be meaningful. |#

(defun record-word-frequency (word position)
  "When we run Sparser in its word-frequency-setting switch setting,
  the function look-at-terminal is setf'd to this function, which is
  passed every word in the document in successive calls (see the driver
  look-at-next-terminal/shell)."
  (when word ;; can be nil in cases where there isn't a word
    (incf *words-in-run*) ;; running total of document length
    (let ((classification (classify-word-for-frequency word position)))
      (when *show-word-freq-collection*
        (format t " ~s" (pname word)))
      (record-word-frequency/over-all word classification))))


(defun do-smart-frequency-count (sentence)
  "Called from scan-terminals-and-do-core when the *smart-frequency-count*
   flag is up. At that point we will have found all polywords, run 
   any applicable FSAs  (e.g. for digit sequences), run word-level completion,
    introduced terminal edges over the words and run any edge-level FSAs."
  (loop for e in (all-tts (starts-at-pos sentence) (ends-at-pos sentence))
     when (edge-p e)
     do (record-word-frequency (word-from-edge e) (pos-edge-starts-at e))))


;;;----------------------------------------------
;;; aggregating frequency information by article
;;;----------------------------------------------

(defun record-word-frequency/over-all (word classification)
  (let ((entry
         (if classification ;; e.g. all function words lumped together
           (frequency-table-entry classification)
           (frequency-table-entry word)))
	(w (or classification
	       word)))
    (if (eq entry :no-entry)
      (make-initial-word-frequency-entry/over-all w)
      (increment-word-frequency-entry/over-all entry w))))


(defun make-initial-word-frequency-entry/over-all (word)
  ;; called the first time a word is seen, i.e. when it isn't already
  ;; in the frequency table.
  (incf *word-types*)
  (setf (gethash word *word-frequency-table*)
        (cons 1
              (list (cons *current-article* 1)
                    )))
  (when *current-article*
    (incf-word-count word *current-article*)))

(defun increment-word-frequency-entry/over-all (entry word)
  "Increments the count in the entry. Would increment the entry's
 per-article 'subentry' if we were using them like we did in
 the 2010 version of the workflow. As of now (March 2020) we're
 keeping the information directly on document elements:
   *current-article* is active for every run and points to an
 instance of the 'article' class.
   *current-doc-collection* covers runs over multiple articles."
  (declare (special *current-article* *current-doc-collection*))
  (incf (first entry))
  (let ((subentry-for-current-article 
	 (if *current-article*
	   (assq *current-article* (cdr entry))
	   (cadr entry)))) ;; only makes sense on a single-document run
    (when *current-article*
      (unless subentry-for-current-article
	(setq subentry-for-current-article
	      `(,*current-article* . 0))
	(rplacd entry (cons subentry-for-current-article
			    (cdr entry)))))
    (incf (cdr subentry-for-current-article))
    (when *current-article*
      (incf-word-count word *current-article*))
    (when *current-doc-collection*
      (incf-word-count word *current-doc-collection*))      
    subentry-for-current-article ))




;;;-----------------------
;;; reporting the results
;;;-----------------------

(defun report-word-increment ()
  (let* ((last-time *word-types-at-start-of-article*)
         (difference (- *word-types*
                        last-time)))
    (format t "~&  ~A words added~%" difference)
    (setq *word-types-at-start-of-article* *word-types*)))


(defun setup-word-frequency-data ()
  (let ((words-counted
         (readout-word-frequency-table-into-a-list)))
    (setq *sorted-word-entries*
          (sort-frequency-list words-counted))
    (length *sorted-word-entries*)))

(defun readout-frequency-table (&optional (stream *standard-output*))
  "Prime reporting routine if just looking all all the words
   and not comparing word frequencies across documents"
  (setup-word-frequency-data)
  (display-sorted-results stream
                          nil ;; just-summary parameter
                          *sorted-word-entries*)
  '*sorted-word-entries*)

(defun display-sorted-results (&optional
                               (stream *standard-output*)
                               (just-summary nil)
                               (list-of-entries *sorted-word-entries*))
  "Walk through the entire vocabulary of the run, which has been
 sorted from least to most frequent. Write out the all the words,
 five per line, on the specified stream, with breaks and labels
 on each frequency increase."
  (format stream "~&~%~A words in a corpus of length ~A"
          (number-of-words-counted) *words-in-run*)
  (count-how-many-at-each-frequency-count)
  (let ((frequency 0)
        (words-on-the-line 0))
    (dolist (entry list-of-entries)
      (when (not (= (cdr entry) frequency))
        ;; the frequency just changed
        (setq frequency (cdr entry)
              words-on-the-line 0)
        (format stream "~&~% ~a words with frequency ~A~%   "
		(how-many-at-frequency-count frequency)
		frequency))
      (unless just-summary
        (princ-word (car entry) stream)
        (write-string "  " stream)
        (incf words-on-the-line)
        (when (= 5 words-on-the-line)
          (format stream "~%   ")
          (setq words-on-the-line 0))))
    (terpri stream)))


;; Subroutine that lets us include a count when displaying
;; sorted results
(defvar *how-many-at-each-frequency-count* (make-hash-table)
  "From numeric frequency to the number of words that occured
 that number of times (once, twice, 57 times, ...).")

(defun how-many-at-frequency-count (n)
  (gethash n *how-many-at-each-frequency-count*))

(defun count-how-many-at-each-frequency-count 
    (&optional (list-of-entries *sorted-word-entries*))
  (let ((frequency 0)
	(count 0))
    (dolist (entry list-of-entries)
      (when (not (= (cdr entry) frequency))
	(setf (gethash frequency *how-many-at-each-frequency-count*) count)
	(setq frequency (cdr entry)
	      count 0))
      (incf count))))


;;--- subroutines for reporting

(defun readout-word-frequency-table-into-a-list ()
  "Returns a list of (,word . ,count)"
  (let ( accumulator )
    (maphash
     #'(lambda (word entry)
         (push (cons word (first entry)) ;; total count, not
               accumulator))             ;; per-document
     *word-frequency-table*)
    accumulator))
;;/// replace that one with this one
(defun readout-wf-table (&optional (table *word-frequency-table*))
  (let ( accumulator )
    (maphash
     #'(lambda (word entry)
         (push (cons word (first entry)) ;; total count, not
               accumulator))             ;; per-document
     table)
    accumulator))


(defun sort-frequency-list (list-of-entries)
  "Sorts the output of readout-word-frequency-table-into-a-list 
   first by count and then alphabetically on the word.
   Ordering is from least frequent to most frequent."
  (sort list-of-entries
        #'(lambda (first second)
            (cond ((< (cdr first)
                      (cdr second))
                   t)  ;; the first goes earlier in the result
                  ((> (cdr first)
                      (cdr second))
                   nil)
                  ((string<
		    (etypecase (car first)
		      (word (word-pname (car first)))
		      (polyword (pw-pname (car first))))
		    (etypecase (car second)
		      (word (word-pname (car second)))
		      (polyword (pw-pname (car second)))))
                   t)
                  ((string>
		    (etypecase (car first)
		      (word (word-pname (car first)))
		      (polyword (pw-pname (car first))))
		    (etypecase (car second)
		      (word (word-pname (car second)))
		      (polyword (pw-pname (car second)))))
                   nil)))))

(defun sort-word-count-pairs (list-of-pairs)
  (sort list-of-pairs ;; (word . number)
        #'(lambda (first second)
            (cond ((> (cdr first) (cdr second))
                   t)
                  ((> (cdr second) (cdr first))
                   nil)
                  ((= (cdr second) (cdr first))
                   (cond
                     ((string> (pname (car first))
                               (pname (car second)))
                      t)
                     ((string> (pname (car second))
                               (pname (car first)))
                      nil)))))))


;;--- Another way to bucket and report the results

(defun word-frequency-profile (&optional
                               (list-of-entries *sorted-word-entries*))
  ;; Scans the global list of sorted (<word> . <count>) data and
  ;; sorts it into buckets. Sets *word-count-buckets* to the list
  ;; of buckets and returns the count.
  (let ((current-count 0)
        list-of-lists  accumulating-words  )
    (dolist (entry list-of-entries)
      (when (not (= current-count (cdr entry)))
        ;; close out the ongoing bucket and start a new one
        (if accumulating-words  ;; startup check
          (then
            (push `(,current-count
                    ,(length accumulating-words)
                    ,@accumulating-words )
                  list-of-lists)
            (setq accumulating-words nil
                  current-count (cdr entry)))
          (setq current-count 1)))
      (push (car entry) accumulating-words))

    ;; close out the last entry
    (push `(,current-count
            ,(length accumulating-words)
            ,@accumulating-words )
          list-of-lists)

    (setq *word-count-buckets* (nreverse list-of-lists))
    (length *word-count-buckets*)))


(defun display-word-frequency-profile (&optional
                                       (stream *standard-output*))
  (unless *word-count-buckets*
    (word-frequency-profile))
  (let ( frequency  count )
    (dolist (entry *word-count-buckets*)
      (setq frequency (first entry)
            count (second entry))
      (format stream "~&~A~4,2T~A~%" frequency count))))


(defun words-with-frequency# (n)
  ;; returns the whole entry, not just the word list
  (unless *word-count-buckets*
    (word-frequency-profile))
  (assoc n *word-count-buckets*))


(defun top-N-frequent-words (n &optional (stream *standard-output*))
  (unless *word-count-buckets*
    (word-frequency-profile))
  (unless *word-count-buckets-most-freq-highest*
    (setq *word-count-buckets-most-freq-highest*
          (reverse *word-count-buckets*)))
  (let ( entry )
    (dotimes (i n)
      (setq entry (nth i *word-count-buckets-most-freq-highest*))
      (format stream "~&~A~5,2T~A" (car entry) (cddr entry)))))



;;--- words as a percentage of the corpus they're derived from

(defun sort-word-frequency-table-most-frequent-first (word-frequency-entries)
  (let ((sort1 (sort-frequency-list (copy-list word-frequency-entries))))
    ;; change to most frequent first
    (nreverse sort1)))

(defvar *word-frequency-corpus-distributions* nil
  "An alist of words by which fraction of the corpus they are in.")

(defun word-frequency-corpus-distribution-by-fractions
    (corpus-length &optional (number-of-parts 12) (table *word-frequency-table*))
  (let* ((words (readout-wf-table table))
	 (sorted (sort-word-frequency-table-most-frequent-first words)))	 
    (word-frequency-corpus-distribution-by-fractions1
     corpus-length number-of-parts sorted)))

(defun word-frequency-corpus-distribution-by-fractions1 (corpus-length
                                                         number-of-parts
                                                         sorted)
  (setq *word-frequency-corpus-distributions* nil)
  (let ((instances-per-fraction (round (/ corpus-length number-of-parts)))
	(iteration 0)	 
	(accumulated-instances 0)
	(words-in-section nil))
    (do* ((pair (car sorted) (car rest))
	  (rest (cdr sorted) (cdr rest))
	  (word (car pair) (car pair))
	  (count (cdr pair) (cdr pair)))
	 ((null pair))
      (push word words-in-section)
      (setq accumulated-instances (+ count accumulated-instances))
      (when (>= accumulated-instances instances-per-fraction)
	(incf iteration)
	(format t "~&fraction ~a contains ~a words~%"
		iteration (length words-in-section))
	(push `(,iteration . ,(nreverse words-in-section))
	      *word-frequency-corpus-distributions*)
	(setq accumulated-instances 0
	      words-in-section nil)))
    ;; last case
    (format t "~&fraction ~a contains ~a words"
	    (incf iteration) (length words-in-section))
    (push `(,iteration . ,words-in-section)
	  *word-frequency-corpus-distributions*)
    (setq *word-frequency-corpus-distributions*
	  (nreverse *word-frequency-corpus-distributions*))
    :done))
      
#|
(write-out-word-frequency-corpus-distributions
  15 "Entire Campbell Biology text"
  "/Users/ddm/ws/Vulcan/ws/frequencies/whole-book-word-distribution.lisp")
|#
(defun write-out-word-frequency-corpus-distributions (fraction corpus-name full-filename)
  (with-open-file (stream full-filename
		   :direction :output
		   :if-exists :overwrite
		   :if-does-not-exist :create)
    (format stream "~&;; Sorting of all of the words in ~a~
                    ~%;; into ~a fractions by word frequency."
	    corpus-name fraction)
    (dolist (pair *word-frequency-corpus-distributions*)
      (let* ((count (car pair))
             (words (cdr pair))
             (sorted (sort (copy-list words) #'alphabetize-words)))
        (format stream "~&~%~%Fraction ~a - ~a words~%~a"
                count (length sorted) sorted)))))



;;;------------------------------------
;;; portions of the tracked vocabulary
;;;------------------------------------

(defgeneric filter-hapax (document)
  (:documentation "Go through the sorted-word-entry list for this
   document and cons a new list that doesn't include any words 
   of frequency 1. Uses *sorted-word-entries* ")
  
  (:method ((document-name symbol))
    (let ((document (get-document document-name)))
      (unless document
        (error "There is no document with the name ~a" document-name))
      (loop for (word . count) in *sorted-word-entries*
         when (> count 1) collect word))))

  


;;;-------------------------
;;; writing out the results
;;;-------------------------

(defgeneric word-frequency-export-form (word &optional stream)
  (:documentation "Writes a def-word entry for a single word
    to the stream using the data in its frequency-table-entry")
  (:method ((word word) &optional (stream *standard-output*))
    (let* ((entry (frequency-table-entry word))
           (doc-counts (cdr entry))
           (pname (word-pname word))
           (forms (map-doc-count-entry word doc-counts)))
      (format stream "(def-word ~s" pname)
      (format stream "~&   ~{ ~a~})~%" forms))))

(defun map-doc-count-entry (word doc-counts)
  "Collect export doc and count data for use in word-frequency-export-form"
  (loop for (doc . count) in doc-counts
       collect (export-doc-count word doc count)))

(defun export-doc-count (word doc count)
  "Format the document and count information for export"
  (let ((normalized (normalized-count word doc))
	(doc-name (name doc)))
    `(,doc-name ,normalized ,count)))


(defun define-2010-words-frequency-data (string doc-freq-data)
  "This is the body of def-word when it is used for repopulating
   or extending word frequency data"
  (declare (special *def-word-definition*))
  (assert (eq *def-word-definition* :2010-frequency)
          () (error "*def-word-definition* should be :2010-frequency"))
  (let* ((word (or (word-named string)
		   (resolve/make string)))
	 (entry (gethash word *word-frequency-table*)))
    (dolist (data doc-freq-data)
      (let ((article (car data))
	    (count (third data)))
	(if (assq article (cdr entry))
	  (then ;; over-write with this count
	    (break "over-write: stub")
	    (let ((new-subentry `(,article . ,count)))
	      (rplacd entry (cons new-subentry (cdr entry)))))
	  (let ((entry `(,count `(,article . ,count))))
	    (setf (gethash word *word-frequency-table*) entry)))))
    entry))

;;--- lifted from word-frequency-reader
(defvar *wf-sections* nil
  "For now, just a dotted pair of section names and counts.")

(defmacro def-section  (section-name word-count)
  ;; e.g. (def-section chapter11 9781)
  `(def-section/expr ',section-name ,word-count))

(defun def-section/expr (section-name word-count)
  (push `(,section-name . ,word-count) *wf-sections*))

(defun section-word-count (section-name)
  (let ((entry (assoc section-name *wf-sections* :test #'eq)))
    (unless entry
      (error "No section named ~a" section-name))
    (cdr entry)))

    
(defun write-def-forms-for-all-words (&optional (stream *standard-output*))
  (let* ((pairs (readout-word-frequency-table-into-a-list))
	 (words (mapcar #'car pairs))
	 (sorted (sort words #'alphabetize-words)))
    (loop for word in sorted
	 do (word-frequency-export-form word stream))))



 


;;;---------------
;;; alphabetizing
;;;---------------
        
;; the sort function
(defun alphabetize-words (w1 w2)
  (let ((pname1 (word-pname w1))
        (pname2 (word-pname w2)))
    (string< pname1 pname2)))

(defun alphabetize-word-list (global-symbol)
  (let ((sorted-list
         (sort (symbol-value global-symbol)
               #'alphabetize-words)))
    (set global-symbol sorted-list)))
 


;;;----------------------------
;;; classifying un/known words
;;;----------------------------

(defparameter *capitalized-word*
  (define-dummy-word/expr 'capitalized-word
    :capitalization :initial-letter-capitalized))

(defparameter *number-word*
  (define-dummy-word/expr 'number-word))

(defparameter *function-word*
  (define-dummy-word/expr 'function-word))

(defparameter *punctuation-word*
  (define-dummy-word/expr 'punctuation-word))


(defun classify-word-for-frequency (word position)
  (declare (ignore word position))
  (error "No classifier has been picked for measuring word ~
          frequency.~%You have to make a call to~
          ~%  Establish-word-frequency-classification"))

(defun establish-word-frequency-classification (keyword function-name)
  "Called with default by word-frequency-setting"
  (unless (fboundp function-name)
    (format t "~&~%Warning: the word frequency classification function~
            ~%  ~A  is not yet defined." function-name))
  (setf (symbol-function 'classify-word-for-frequency)
        (symbol-function function-name))
  (setq *word-frequency-classification* keyword))


(defun wf-classification/ignore-caps (word position)
  (if (word-rules word) ;; known
    (wf-classification/ignore-caps/known word position)
    (let ((capitalization (pos-capitalization position)))
      (case capitalization
	(:digits *number-word*)
	(otherwise
         (let ((stem (if *stem-words-for-frequency-counts*
		  (stem-form word) ;; in rules/tree-families/morphology1.lisp
		  (word-pname word))))
         (typecase stem
           (word stem)
           (string (or (word-named stem)
                       (define-word/expr stem)))
           (otherwise
            (push-debug `(,stem ,word ,position ,capitalization))
            (error "Unexpected type of stem")))))))))

(defun wf-classification/ignore-caps/known (word position)
  "Unclear that capitalization is meaningful unless we can distinguish 
   sentence-internal from initial and get the initial proper names 
   via a workable heuristic."
  (cond ((polyword-p word)
         word)
        ((get-tag :function-word word)
         (if *include-function-words-in-frequency-counts*
             word
             (else (pushnew word *function-words-seen-in-run*)
                   *function-word*)))
        (t
         (ecase (pos-capitalization position)
           (:lower-case word) 
           (:punctuation
            (if *include-punctuation-in-frequency-counts*
                word
                (else (pushnew word *punctuation-seen-in-run*)
                      *punctuation-word*)))
           (:digits *number-word*)
           ;;/// Need to include the number word (ordinals and cardinals)
           ;; in this generalization
           ((or :initial-letter-capitalized
                :all-caps
                :mixed-case
                :single-capitalized-letter)
            word )))))

#| (establish-word-frequency-classification :ignore-capitalization
                                            'wf-classification/ignore-caps)  |#


;;--- Porter Stemming

#| Lifted from wf-classification/ignore-caps
   when shifted to Sparser-internal stemmer
    (let ((capitalization (pos-capitalization position))
	  (stem (word-pname word))) ;; for default when not stemming
      (when *stem-words-for-frequency-counts*
	(let ((pname (word-pname word)))
	  (unless (eq capitalization :lower-case)
	    (setq pname (string-downcase pname)))
	  (setq stem (apply-Porter-stemmer pname))
	  ;;/// restore final "e" ?
	  (unless (string-equal stem pname)
	    (record-original-from-stem stem pname))))
|#

(defun apply-Porter-stemmer (lowercase-string)
  (cl-user::stem lowercase-string))

(defvar *stems-to-original-word-string* (make-hash-table))

(defun unporter (stemmed-string)
  (gethash stemmed-string *stems-to-original-word-string*))

(defun record-original-from-stem (stemmed-string original)
  (pushnew original 
	   (gethash stemmed-string *stems-to-original-word-string*)))
  

;;;--------
;;; shells
;;;--------

;; (initialize-word-frequency-data)
;; (readout-frequency-table)

(defun f/wf (namestring)
  "Original driver. Works over a single file. Holds all the
  computed information in globals that have to be manually
  harvested and dealt with before the next run."
  (word-frequency-setting)
  (analyze-text-from-file namestring))


(defgeneric count-word-frequencies (document)
  (:documentation "Gets the text to be analyzed and counted
   from the document (doc-set, etc.) and stores the results 
   on the object. ")

  (:method ((doc document))
    (word-frequency-setting)
    (initialize-word-frequency-data)
    (let ((filename (doc-location doc)))
      (analyze-text-from-file filename)
      (setf (token-count doc) *words-in-run*)
      doc))

  (:method ((doc-set document-set))
    (word-frequency-setting)
    (initialize-word-frequency-data)
    ;; need before/after-{document type} methods to provide 
    ;; a hook for collecting. Perhaps a 'we're counting words' mode
    ;; special for them to consult? Or perhaps the equivalent would
    ;; be something that's set anyway to support word-frequency settings
    ;; that's easily consulted.
    (do-document-as-stream-of-files doc-set)))



