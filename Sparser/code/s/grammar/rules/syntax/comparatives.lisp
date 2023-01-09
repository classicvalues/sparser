;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1994,2014-2020  David D. McDonald  -- all rights reserved
;;;
;;;      File:   "comparatives"
;;;    Module:   "grammar;rules:syntax:"
;;;   Version:   November 2021

;; initiated 7/29/94. 10/24/94 added defdata
;; 7/20/14 Added a lemma for "comparative"

(in-package :sparser)

#| A predication based on a comparative adjective (or superlative)
makes a statement about the value of some attribute (e.g. size) of
its 'subject' that compares it to the values of that attribute
in some reference set. 

That 'subject' individual must be able to take that attribute (e.g. it
isa 'has-size'). The attribute, e.g. size, is scalar. 

Comparatives also convey the 'direction' of the difference from 
the reference set. Trips calls that 'orientation'.

abstract > abstract-region > 
   attribute-value > size-value > big > bigger
|#

;;;----------------------------------
;;; comparative adjective contructor
;;;----------------------------------

;; TO-DO (11/5/19)
;;   Figure out how to handle direction
;;   Put make the mumble resource for the adj in the attribution

(defun setup-comparatives (base-adj attribute-name base-pname
                           direction-flag er est)
  "Called from the define function of an attribute (e.g. define-size)
   after the category for the  attribute-value ('base-adj') has been
   created. Make categories for the comparative ('er') and superlative ('est')
   forms that inherit from that base. 

   The morphology routines for constructing these words by rule is not
   particularly good at it, so for that reason and because some
   comparative paradigms are irregular, there is a provision to pass
   the strings for 'er' and 'est' in explicitly.

   Note that since we're using define-function-term to do all the heavy lifting
   we get an individual along with the category, and that individual
   is the referent of the constructed rule."
  
  (let* ((base-word (word-named base-pname))
         (er-word
          (if er
            (resolve/make er)
            (make-comparative/superlative
             base-word :suffix "er" :y-suffix "ier")))
         (est-word
          (if est
            (resolve/make est)
            (make-comparative/superlative
             base-word :suffix "est" :y-suffix "iest"))))

    (when (category-named er-word) ; (category-named est-word) too?
      (format t "~&~%Constructed comparative ~s clashes with defined category~%~%"
              er-word)  ;; 'number' from 'numb' out of comlex
      (return-from setup-comparatives))
    
    (multiple-value-bind (er-category er-indiv er-rule)
        (define-function-term er-word 'comparative-adjective
          :super-category (cat-name base-adj)
          :bindings `(attribute ',attribute-name)
          :mixins '(comparative)
          :rule-label 'comparative)

      (multiple-value-bind (est-category est-indiv est-rule)
          (define-function-term est-word 'superlative-adjective
            :super-category (cat-name base-adj)
            :bindings `(attribute ',attribute-name)
            :mixins '(superlative)
            :rule-label 'superlative)

        (set-direction direction-flag base-adj er-category est-category)

        ;; more cross references?
        (setf (get-tag :comparative base-adj) er-category)
        (setf (get-tag :superlative base-adj) est-category)

        ;; n.b. nobody presently is gathering up these values
        (values er-category er-indiv er-rule
                est-category est-indiv est-rule)))))


(defun setup-anonymous-graded-adjective (base-word
                                         comparative-entry superlative-entry
                                         cat-name-to-use)
  "Called from setup-adjective for the case where the Comlex entry 
   includes explicit 'er' and 'est' words. These have no real
   meaning -- no associated attribute -- so we have to make
   one for them."
  ;;(push-debug `(,base-word ,comparative-entry ,superlative-entry))
  (let* ((pname (pname base-word))
         (attribute (create-scalar-attribute base-word))
         (comparative (first comparative-entry))
         (superlative (first superlative-entry))
         (base-adjective (define-adjective pname :cat cat-name-to-use)))
    (unless (and (> (length comparative) 5)
                 (string-equal "more" (subseq comparative 0 4)))
      ;; presumably the superlative is "most xx"
      ;; We let these get formed by rule
      (setup-comparatives base-adjective
                          (cat-name attribute)
                          pname
                          nil ;  direction-flag
                          comparative ; er
                          superlative ; est
                          ))))

(defgeneric create-scalar-attribute (base)
  (:method ((w word))
    (create-scalar-attribute (pname w)))
  (:method ((pw polyword))
    (create-scalar-attribute (hyphenated-string-for-pw pw)))
  (:method ((pname string))
    (let* ((ness-name
            (intern (string-append (string-upcase pname) "-" '#:ness)
                    (find-package :sparser)))
           (form `(define-category ,ness-name
                      :specializes scalar-attribute))
           (category (eval form)))
      category)))

(defun er-test-entry (pname)
  (declare (special *primed-words*))
  (let* ((word (resolve/make pname))
         (entry (gethash pname *primed-words*)))
    (values word entry)))

(defun er-test-jig (pname)
  (multiple-value-bind (word entry)
      (er-test-entry pname)
    (when entry
      (continue-unpacking-lexical-entry word entry))))

;;;---------------------------------------------------
;;; for the :adjective head specifier or from Comlex
;;;---------------------------------------------------

#| These two function compensate for not having comparative
or superlative realization options. The categories we instantiate
here use :word as their realization spec to ensure that nobody
mucks with the word under the covers. But the form specification
is also the basis of the form label on the rule that realization
creates, so these functions shift it over.
   They're also recruited by the morphology code itself to get
a reasonable referent for the cases that don't go through this
route. That threading requires them to return a rule. 
   Worse still, be have some duplicate definitions going on
(e.g. "cycle" in core/collections and in biology/taxonomy)
so to return a rule in those cases we have to look for
comparative rather than content-word.  |#

(define-category comparative-modifier
  :specializes attribute-value
  :mixins (comparative)
  :index (:permanent :key name)
  :realization (:word name)) ;; form category is content-word

(defun define-comparative (word)
  "Called from setup-comparative and by make-comparative-rules in
   the morphology of adjectives"
  (define-or-find-individual 'comparative-modifier :name word)
  (switch-form-to-comparative word))

(defun switch-form-to-comparative (word)
  ;; simpler while designing these than extending the head keywords
  (let ((rule (find-form-cfr word category::content-word)))
    (when rule
      (setf (cfr-form rule) category::comparative-adjective))
    (or rule
        (find-form-cfr word category::comparative-adjective))))


(define-category superlative-modifier
  :specializes attribute-value
  :mixins (superlative)
  :index (:permanent :key name)
  :realization (:word name))

(defun define-superlative (word)
  "Called from setup-superlative (Comlex) and from the adjective
   handler in morphology"
  (define-or-find-individual 'superlative-modifier :name word)
  (switch-form-to-superlative word))

(defun switch-form-to-superlative (word)
  (let ((rule (find-form-cfr word category::content-word)))
    (when rule
      (setf (cfr-form rule) category::superlative-adjective))
    (or rule
        (find-form-cfr word category::superlative-adjective))))



(defun modify-comparatives-rule-labels (base-word er-word est-word)
  (let* ((base-rule (find-form-cfr base-word category::adjective))
         (base-label (cfr-category base-rule))
         (er-rule (find-form-cfr er-word category::comparative-adjective))
         (est-rule (find-form-cfr est-word category::superlative-adjective)))
    (setf (cfr-category er-rule) base-label)
    (setf (cfr-category est-rule) base-label)))
       

;;;----------------------------------------------
;;; for anonymous comparatives, e.g. from Comlex
;;;----------------------------------------------
;;--- Minimal treatment for when we don't know the attribute
;;    and have no principled way to determine what variable to bind

(define-category comparative-modification
  :specializes scalar-attribute
  :bindings (var (find-variable-for-category 'modifier 'top))
  :documentation "Modeled on comparative-quantification")



;;;-----------------
;;; base categories
;;;-----------------

;; 'comparative' is defined in categories.lisp as a form category,
;; which happens to make it a referential-category.
;;/// Consider having define-mixin-category rework the object to fit

(define-mixin-category shared-comparative-and-superlative
  :instantiates nil
  :specializes adds-relation
  :binds ((direction) ;; more/less
          (reference-set)) ;; holds what we're comparing it to
  :documentation "These could be on comparative and superlatives
 could inherit from comparative, but that would make a superative
 also be a comparative, which would be messy to reason with.")
;;################################
(define-mixin-category comparative
  ;; inherits the variable name and attribute from attribute-value
  :specializes attribute-value
  :lemma (:common-noun "comparative")
  :mixins (shared-comparative-and-superlative)
  :realization (:adj "comparative"
                :adverb "comparatively")
  :documentation "This is included in (mixed into) every comparative.
 Comparatives are a particular kind of attribute
 value, so their principal link is to the attribute they
 correspond to, and their second is to the direction
 on the scalar dimension of the attribute that they
 pick out (Trips calls this 'orientation'). They naturally
 fall into contrastive pairs ('larger', 'smaller'), but
 that's a property of the attribute rather than the
 particular comparative.
   Even as a bare adjective, a comparative is implicitly relative
 to some 'reference-set'. That variable is bound when the
 comparative is in composition with than phrase.")

(define-mixin-category superlative
  :specializes attribute-value
  :mixins (shared-comparative-and-superlative)
  :realization (:adj "superlative")
  :documentation "Shares properties with comparatives, but picks
 out the end of its reference-set's scalar attribute: 'biggest',
 'smallest'.")


;;--- direction

(defun set-direction (direction-flag base-class er-class est-class)
  (unless direction-flag ;; reasonable default
    (setq direction-flag :+))
  (let ((direction (ecase direction-flag (:+ :more) (:- :less))))
    ;;/// so how do we encode this in a useful way
    ))
#+ignore  ;; needs redesign
(define-category direction-of-comparison
  :specializes comparative 
  :documentation "Nothing neeeds to be done here
    other than provide a distinguishing name
    that we can attach inferences to.")
#+ignore
(define-category more-than ;; => 'more' once they're done right
    :specializes direction-of-comparison)
#+ignore
(define-category less-than ;; => 'less'
    :specializes direction-of-comparison)


;;;-----------------------------
;;; relations over comparatives
;;;-----------------------------

;;--- "a bigger block"
;; Done by comparative-adj-noun-compound
;; If comparative derives from an attribute that determines what variable
;; to bind on the head, otherwise we treat it as though it was
;; a copula ("the block is bigger") -- interpret the head as the adjective's
;; head and connect them via a predication.

#| Functionally a comparative (or superlative) is an adjective
that modifies some nominal head, as in "a bigger block".
  -- That composition is done by ,
  which uses variable-for-attribute to see what variable to
  bind (e.g. 'size'). The value that's bound is a new instance
  (individual) of comparative-attribution. This is where the
  reference-set is introduced.

The 'than clause' that explicitly identifies the reference set
is assimilated in one of two ways.
  (a) In constructions like "bigger than a breadbox" we have both
elements of the attribution available at once. The syntax function
that assembles it is make-comparative-adjp-with-np and the
result is a {comparative, superlative}-adjp.
  (b) In a construction like "a bigger block than that one"
we are appling the predicate [bigger than that block] to the
head to form a comparative-predication. The syntax function
is maybe-extend-comparative-with-than-np, which has to do
a bit of digging to find the comparative-attribution since
the np for "a bigger block" is interpreted before the than phrase
is seen.  |#

;; "bigger than a breadbox"
#+ignore ;; move the reference-set up to comparative
(define-category comparative-attribution
  :specializes quality-value-predicate
  :documentation "This represents the 
   combination of the comparative (or superlative) term
   and the reference set it's being compared to."
  :binds ((reference-set))
  :restrict ((value comparative))
  :index (:permanent :sequential-keys value reference-set))

(define-category comparative-predication
  :specializes has-attribute
  :documentation "A predication that is based on applying
  a comparative-attribution to something, as in 'b1 is
  bigger than b2', which applies the predicate 'bigger 
  than b2' to the individual 'b1'. TRIPS would probably
  use 'figure' where we're using (for the moment) item.")


(define-category qualified-attribute ;; "more precise"
  :specializes quality-value-predicate
  :mixins (comparative)
  :binds ((attribute)
          (comparative comparative))
  :documentation "Provides an envelop for compound comparatives
  formed with 'more', 'less', or any other comparative quantifier.
  Provides the hook that's needed to link 'than' complements to
  the quantifier (value of the 'comparative' variable). These are
  formed directly by application of the rule that composes a
  comparative with an an adjective.")


;; 11/24/20 'many more' is handled by a syntactic rule
;; #<PSR-1450 comparative → {quantifier comparative}>
;; that calls the syntax function quantify-comparative
;;
(define-category quantified-comparative ;; "many more"
  :specializes comparative
  :binds ((quantifier quantifier)
          (comparative comparative))
  :documentation "Gives us a base representation of the composition
    of a quantifier (many, some, any, all) and a comparative,
    maybe only 'more' and 'less. The meaning of the composition
    is strictly dependent on the choice of quantifer and the
    reference set of the comparison, so computing it will depend
    on having all those elements in hand and will be a matter
    of applying word-specific k-methods.")



;;;-------- Earler way to doing these that's not used any longer.
;;;    Retained to mine the old ideas

#+ignore
(defun specialize-comparative (attribute)
  "Make a new category that specializes comparative
   by binding the attribute. The result will be stored
   by binding the 'comparative' variable on the 
   attribute category."
  (let ((*legal-to-add-bindings-to-categories* t))
    (declare (special *legal-to-add-bindings-to-categories*))
  (let* ((c-name (s-intern (cat-name attribute) '#:-comparative))
         (s-name (s-intern (cat-name attribute) '#:-superlative))
         (c-category 
          (define-category/expr c-name
               `(:specializes comparative
                 :instantiates self
                 :bindings (attribute ,attribute)
                 :rule-label comparative
                 :index (:permanent :key name)
                 :realization (:word name))))
         (s-category 
          (define-category/expr s-name
               `(:specializes superlative
                 :instantiates self
                 :bindings (attribute ,attribute)
                 :rule-label superlative
                 :index (:permanent :key name)
                 :realization (:word name)))))
    (bind-variable 'comparative c-category attribute)
    (bind-variable 'superlative s-category attribute)
    (specialize-directions c-category attribute)
    (specialize-directions s-category attribute)
    c-category)))

#+ignore
(defun specialize-directions (comparative attribute)
  "Define a pair of categories, one representing more
   the other representing less. Both have to be 'terminal'
   categories, in the sense that we can instantiate
   properly indexed individuals from them."
  (let* ((base-name (cat-name comparative))
         (more-name (s-intern base-name '#:-more))
         (less-name (s-intern base-name '#:-less)))
    (let ((m-category
           (define-category/expr more-name
               `(:specializes more-than
                 :instantiates comparative
                 :bindings (attribute ,attribute)
                 :rule-label comparative
                 :index (:permanent :key name)
                 :realization (:word name))))
          (l-category
           (define-category/expr less-name
               `(:specializes less-than
                 :instantiates comparative
                 :bindings (attribute ,attribute)
                 :rule-label superlative
                 :index (:permanent :key name)
                 :realization (:word name)))))
      (bind-variable 'more m-category comparative)
      (bind-variable 'less l-category comparative)
      comparative)))



;;-------------------------------------------------------------------
;;--- old / alterantives keeping them around to mine/reinvigorate
#|
(define-category  comparative
  :instantiates nil
  :specializes nil
  :binds ((word  :primitive word))   ;; just a stand-in
  :index (:permanent :key word)
  :lemma (:adjective "comparative")
  :realization (:word word))

(defun define-comparative (string &key rule-label discriminator)
  (define-function-term string 'comparative
    :rule-label rule-label
    :discriminator discriminator
    :tree-families '(pre-adv-adverb pre-adj-adverb)))  |#

(define-autodef-data  'comparative
  :display-string  "comparative adjectives"
  :form 'define-comparative
  :dossier "dossiers;comparatives"
  :module *comparatives*
  :description "a word, often ending in 'er', that fits in the context '___ than'"
  :examples "\"fewer\", \"more\", \"better\"" )

  #| This scheme says the denotation of a comparative word ("bigger")
 is a category. (The table in allowable-referential-edge? ensures this.)
 The reason is that the identity of a comparative depends on all three
 of its values at once. 

    (let ((er-category
           (define-category/expr (name-to-use-for-category er-word)
               `(:specializes comparative
                 :instantiates self
                 :bindings (name ,er-word
                            attribute ,attribute
                            direction ,direction))))
          (est-category
           (define-category/expr (name-to-use-for-category est-word)
               `(:specializes comparative
                 :instantiates self
                 :bindings (name ,est-word
                            attribute ,attribute
                            direction ,direction)))))

    (direction (ecase direction-flag
                     (:+ (find-individual 'direction :name "up"))
                     (:- (find-individual 'direction :name "down")))) |#
