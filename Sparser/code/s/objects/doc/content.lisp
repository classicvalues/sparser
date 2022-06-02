;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:(SPARSER LISP) -*-
;;; copyright (c) 2013-2022 David D. McDonald  -- all rights reserved
;;;
;;;     File:  "content"
;;;   Module:  "objects;doc:"
;;;  Version:  June 202

;; initiated 3/13/13. Elaborated through 3/29/13. 9/17/13 fan-out
;; from sections make-over. 10/2/19 Fleshed out general notion of
;; a container and set up simple accumulator for sentences.
;; 5/12/15 Reorganized a good deal and pulled out fresh-contents
;; to go in drivers/forest/parsing-containers.lisp. Moved them
;; back here 6/11/15 reincarnated as 'install-contents' that only
;; does it once. Added more mixins to the content classes for
;; organizing aggregation of their relations and entities as well
;; as record their rhetorical aspects.

(in-package :sparser)


;;;------------
;;; containers
;;;------------

(defclass container (named-object)
  ((backpointer :initarg :in :accessor bkptr
    :documentation "backpointer to the document object that it's part of"))
  (:documentation "Common super class for all container-like things"))

;;--- sentence
           
(defclass sentence-content (container
                            parsing-status
                            local-layout ; from sweep-sentence-treetops
                            epistemic-status ; from rhetoric
                            entities-and-relations
                            sentence-discourse-history ;; lifo instances
                            sentence-text-structure ;; subject
                            records-of-delayed-actions
                            accumulate-items ; noteworthy categories
                            text-relations ; Grok chunk analysis
                            ordered)
  ((metadata :initform nil :accessor metadata
    :documentation "Metadata describing choices made by Sparser."))
  (:documentation "From container we get :in to point back to the
    sentence. From ordered we get previous and next so we can link
    the directly without having to go to the sentence objects."))
;; n.b. text-relation (singular) is for grok
;;   in analyzers/sdmp/text-relation-class.lisp


(defmethod print-object ((c sentence-content) stream)
  (print-unreadable-object (c stream :type t)
    (let ((sentence (bkptr c)))
      (format stream "p~a -- "
              (pos-token-index (starts-at-pos sentence)))
      (if (and (slot-boundp sentence 'ends-at-pos)
               (ends-at-pos sentence))
        (format stream "p~a" (pos-token-index (ends-at-pos sentence)))
        (format stream "?")))))


;;--- paragraph

(defclass paragraph-content (container
                             aggregated-bio-terms
                             sentence-parse-quality
                             sentence-tt-counts ; assess-sentence-analysis-quality
                             paragraph-characteristics
                             epistemic-state ;; from rhetoric (empty)
                             discourse-relations ;; rhetoric
                             debris-layout
                             )
  ()
  (:documentation "Will want a bunch more structure just over
    the enties for the purpose of facilitating anaphora.
    Story structure might be paragraph based too."))


(defclass paragraph-features (container
                              sentence-parse-quality
                              sentence-tt-counts
                              accumulate-items
                              paragraph-characteristics)
  ()
  (:documentation "Populated by collect-text-characteristics called
    on the paragraph by after-actions. Concerned more with form than
    semantic content"))


;;--- larger

(defclass section-content (container
                           aggregated-bio-terms
                           sentence-parse-quality)
  ()
  (:documentation "For Biology or Covid"))

(defclass section-features (container
                            sentence-parse-quality
                            sentence-tt-counts
                            accumulate-items
                            paragraph-characteristics)
  ()
  (:documentation "For non-Bio, more general"))



(defclass article-content (container
                           aggregated-bio-terms
                           sentence-parse-quality
                           text-relations)
  ()
  (:documentation "For Biology or Covid"))

(defclass article-features (container
                            sentence-parse-quality
                            sentence-tt-counts
                            accumulate-items
                            paragraph-characteristics)
  ()
  (:documentation "For non-Bio, more general"))



;;;------------------------
;;; conditional containers
;;;-----------------------

(defparameter *container-for-sentence* :complex ;; :situation
  "Switch parameter for the kind of container we make for
   a sentence, which could be designed for simple accumulation,
   presumably structured accumulation, long-distance parse state
   or (the motive for all this) a situation.")

(defun designate-sentence-container (&optional (keyword *container-for-sentence*))
  (declare (special *container-for-sentence*))
  (setq *container-for-sentence* keyword))

(defun make-sentence-container (sentence)
  "N.b. this called from start-sentence directly, not by a install-contents
   method (probably it should be). The (setf contents) call is there. These
   variants just determine what content class the sentences will have."
  (declare (ignore sentence) (special *container-for-sentence*))
  (ecase *container-for-sentence*
    (:situation (make-sentence-container/situation sentence))
    (:complex (make-instance 'sentence-content :in sentence))))



(defparameter *container-for-paragraph* :biology "Default choice")

(defun designate-paragraph-container (&optional (keyword *container-for-paragraph*))
  (declare (special *container-for-paragraph*))
  (setq *container-for-paragraph* keyword))

(defun make-paragraph-content-container/bio (p)
  (make-instance 'paragraph-content :in p))

(defun make-paragraph-content-container/texture (p)
  (make-instance 'paragraph-features :in p))

(defmethod install-contents ((p paragraph))
  "The setf is done in the caller, which should always be
   begin-new-paragraph, regardless of where we're getting
   the paragraphs from."
  (ecase *container-for-paragraph*
    (:biology (make-paragraph-content-container/bio p))
    (:texture (make-paragraph-content-container/texture p))))


(defparameter *container-for-sections* :biology)

(defun designate-section-container (&optional (keyword *container-for-sections*))
  (declare (special *container-for-sections*))
  (setq *container-for-sections* keyword))


(defparameter *container-for-articles* :biology)

(defun designate-article-container (&optional (keyword *container-for-articles*))
  (declare (special *container-for-articles*))
  (setq *container-for-articles* keyword))



;;;---------------------------------------------------------
;;; Setting the context of the different levels of document
;;;---------------------------------------------------------

(defgeneric install-contents (document-element)
  (:documentation "Instantiate the appropriate content class for
    this class of document element. Assumes that the elements are
    permanent and checks to insure that multiple passses over
    an element will not replace the original contents instance."))

(defmethod install-contents ((a article))
  (unless (contents a)
    (ecase *container-for-articles*
      (:biology (setf (contents a) (make-instance 'article-content :in a)))
      (:texture (setf (contents a) (make-instance 'article-features :in a))))))

(defmethod install-contents ((sos section-of-sections))
  (unless (contents sos)
    (setf (contents sos) (make-instance 'section-content :in sos))))

(defmethod install-contents ((s section))
  (unless (contents s)
    (ecase *container-for-sections*
      (:biology (setf (contents s) (make-instance 'section-content :in s)))
      (:texture (setf (contents s) (make-instance 'section-features :in s))))))

(defmethod install-contents ((te title-text))
  (unless (contents te)
    (setf (contents te) (make-instance 'paragraph-content :in te))))



;;;---------------------------
;;; Grok code to rehabilitate
;;;--------------------------

#|   Definition for Grok
  "Supplies the content field of an article"
  ;; placeholder for resource -- but only via a generating macro that
  ;; has some generality.
  (let ((contents (make-instance 'text-relation-contents :container article))
        (symbol (name article)))
    (if symbol
      (setf (name contents) symbol)
      (setf (name contents) :no-name-in-article))
    contents))
|#

;;--- printing item list

(defmethod print-object ((c accumulate-items) stream)
  (print-unreadable-object (c stream :type t)
    (let ((items (items c))
          (doc-object (bkptr c)))
      (format stream "~a  " (type-of doc-object))
      (if items
        (format stream "~a items" (length items))
        (format stream "empty")))))


;;--- adding items

(defgeneric add-to-container (item container)
  (:documentation "Handles the odities of putting the items into
     the correct place according to the type of the container.
     The 'note' function sets the 'list' slot directly.")
  (:method ((item t) (s sentence))
    (tr :adding-to-container item s)
    (let* ((container (contents s))
           (list (items container)))
      (setf (items container) (cons item list)))))


;;--- other operations

(defgeneric display-contents (container &optional stream)
  (:documentation "Print the contents of the container to
     the stream in a form designed to inform people"))

(defmethod display-contents  ((c accumulate-items)
                              &optional (stream *standard-output*))
  (format stream "~&~a" (bkptr c))
  (dolist (item (items c))
    (format stream "~%~5T~a~%" item)))


;;----------- Grok text-relations operations ----------

(defmethod display ((tc text-relations)) ;; add a stream?
  (format t "~&  ~a heads~
             ~%  ~a clasifier-heads~
             ~%  ~a modifier-heads~
             ~%  ~a adjacencies  "
          (length (head-relations tc))
          (length (classifier-head-relations tc))
          (length (modifier-head-relations tc))
          (length (adjacency-relations tc)))
  tc)

(defun add-text-relation-to-article (relation instance)
  (unless *current-article*
    (error "Initialization/threading error. No value for *current-article*"))
  ;;(push-debug `(,relation ,instance)) (break "add text relation: ~a" relation)
  (let ((content-obj (contents *current-article*)))
    (case (name relation)
      (text-relationships::head
       (push instance (head-relations content-obj)))
      (text-relationships::classifier-head
       (push instance (classifier-head-relations content-obj)))
      (text-relationships::modifier-head
       (push instance (modifier-head-relations content-obj)))
      (text-relationships::adjacent
       (push instance (adjacency-relations content-obj)))
      (otherwise
       (push-debug `(,relation ,instance))
       (error "No provision for storing ~a yet" relation)))))
