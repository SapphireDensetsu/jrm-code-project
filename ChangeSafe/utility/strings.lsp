;;; -*- Mode: Lisp; Encoding: (:unicode :little-endian t) -*-
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;          Copyright © 2002 ChangeSafe, LLC
;;;;          ALL RIGHTS RESERVED.
;;;;
;;;;          ChangeSafe, LLC CONFIDENTIAL and PROPRIETARY material.
;;;;
;;;;          ChangeSafe, LLC
;;;;
;;;; This software and information comprise valuable intellectual
;;;; property and trade secrets of ChangeSafe, LLC, developed at
;;;; substantial expense by ChangeSafe, which ChangeSafe intends to
;;;; preserve as trade secrets.  This software is furnished pursuant
;;;; to a written license agreement and may be used, copied,
;;;; transmitted, and stored only in accordance with the terms of such
;;;; license and with the inclusion of the above copyright notice.
;;;; This software and information or any other copies thereof may not
;;;; be provided or otherwise made available to any other person.  NO
;;;; title to or ownership of this software and information is hereby
;;;; transferred.  ChangeSafe, LLC assumes no responsibility for the
;;;; use or reliability of this software.
;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Localization strings for ChangeSafe

;;; NOTES:
;;;   Prefer `ChangeSet' to `Change Set'


(in-package "CSF/UTILITY")

(proclaim (standard-optimizations))

(eval-when (:load-toplevel :execute)
  (export '(csf/config::*default-locale*)
          "CSF/CONFIG")
  (export '(locale
            locale/language
            locale/country

            localized-string
            parse-locale
            format-in-language
            server-locale)))

(defconstant *locale-table*
  (if (and (boundp '*locale-table*)
           (symbol-value '*locale-table*))
      (symbol-value '*locale-table*)
      (make-hash-table :test #'equal)))

(defclass locale ()
  ((language :initarg :language
             :reader locale/language)
   (country  :initarg :country
             :reader locale/country)))

(defun locale? (thing)
  (typep thing 'locale))

(defun make-locale (language country)
  (let* ((key (cons language country))
         (probe (gethash key *locale-table*)))
    (or probe
        (setf (gethash key *locale-table*)
              (make-instance 'locale
                             :language language
                             :country country)))))

(defmethod print-object ((locale locale) stream)
  (print-unreadable-object (locale stream)
    (format stream "LOCALE ~a~@[-~a~] ~a~@[ - ~a~]"
            (iso-639/code (locale/language locale))
            (when (locale/country locale)
              (iso-3166/code (locale/country locale)))
            (iso-639/english-name (locale/language locale))
            (when (locale/country locale)
              (iso-3166/english-name (locale/country locale))))))

(defun parse-locale (string)
  (check-type string (or string symbol))
  (cond ((symbolp string) (parse-locale (symbol-name string)))
        ((= (string-length string) 5)
         (let ((language (parse-iso-639-code (subseq string 0 2)))
               (country  (parse-iso-3166-code (subseq string 3 5))))
           (when (and language country)
             (make-locale language country))))
        ((= (string-length string) 2)
         (let ((language (parse-iso-639-code (subseq string 0 2))))
           (when language
             (make-locale language nil))))
        (t nil)))

(defvar-unbound *default-locale*
  "The locale used when not otherwise specified.")

(defvar-unbound *server-locale*
  "The locale the server is running on.  Determined from the OS.")

(defun server-locale ()
  (if (boundp '*server-locale*)
      *server-locale*
      (setq *server-locale* (parse-locale (os-server-locale)))))

(defconstant *default-string-table*
  (if (and (boundp '*default-string-table*)
           (symbol-value '*default-string-table*))
      (symbol-value '*default-string-table*)
      (make-hash-table :test #'eq)))

(defun default-string (string-identifier)
  (check-type string-identifier keyword)
  (gethash string-identifier *default-string-table* (symbol-name string-identifier)))

(defsetf default-string (string-identifier) (new-value)
  `(SETF (GETHASH ,string-identifier *DEFAULT-STRING-TABLE*) ,new-value))

(defun localized-string (string-identifier &optional (locale *default-locale*))
  (if (locale? locale)
      (let ((country (locale/country locale)))
        (or (and country
                 (iso-3166/country-string country string-identifier))
            (iso-639/language-string (locale/language locale) string-identifier)
            (default-string string-identifier)))
      (default-string string-identifier)))

(defun set-localized-string (string-identifier locale value)
  (check-type string-identifier keyword)
  (check-type locale locale)
  (check-type value string)
  (let ((country (locale/country locale)))
    (if country
        (setf (iso-3166/country-string country string-identifier) value)
        (setf (iso-639/language-string (locale/language locale) string-identifier) value))))

(defsetf localized-string (string-identifier locale) (new-value)
  `(SET-LOCALIZED-STRING ,string-identifier ,locale ,new-value))

(defun localized-formatter (format-identifier &optional (locale *default-locale*))
  (flet ((missing (stream &rest args)
           (format stream "Missing format string for ~s for locale ~s.  Args are ~s"
                    format-identifier
                    locale
                    args)))
    (if (locale? locale)
        (let ((country (locale/country locale)))
          (or (and country
                   (iso-3166/country-formatter country format-identifier))
              (iso-639/language-formatter (locale/language locale) format-identifier)
              #'missing))
      #'missing)))

(defun set-localized-formatter (format-identifier locale value)
  (check-type format-identifier keyword)
  (check-type locale locale)
  (let ((country (locale/country locale)))
    (if country
        (setf (iso-3166/country-formatter country format-identifier) value)
        (setf (iso-639/language-formatter (locale/language locale) format-identifier) value))))

(defsetf localized-formatter (format-identifier locale) (new-value)
  `(SET-LOCALIZED-FORMATTER ,format-identifier ,locale ,new-value))

(defmacro defstring (string-identifier &rest specs)
  (if (and (stringp (car specs))
           (null (cdr specs)))
      `(EVAL-WHEN (:LOAD-TOPLEVEL :EXECUTE)
         (SETF (DEFAULT-STRING ,string-identifier) ,(car specs)))
      `(EVAL-WHEN (:LOAD-TOPLEVEL :EXECUTE)
         ,@(map 'list (lambda (spec)
                        (if (stringp spec)
                            `(SETF (DEFAULT-STRING ,string-identifier) ,spec)
                            `(SETF (LOCALIZED-STRING ,string-identifier (PARSE-LOCALE ,(symbol-name (car spec))))
                                   ,(cadr spec))))
                specs))))

(defmacro defformat (format-identifier arglist &rest specs)
  (let ((stream-specifier (gensym "STREAM-")))
  `(EVAL-WHEN (:LOAD-TOPLEVEL :EXECUTE)
     ,@(map 'list (lambda (spec)
                    `(SETF (LOCALIZED-FORMATTER ,format-identifier (PARSE-LOCALE ,(symbol-name (car spec))))
                           (LAMBDA (,stream-specifier ,@arglist)
                             (CL:FORMAT ,stream-specifier ,(cadr spec) ,@(cddr spec)))))
            specs))))

(defun format-in-language (locale stream format-identifier &rest format-args)
  "Like FORMAT, but takes an additional LOCALE specifier."
  (apply (localized-formatter format-identifier (etypecase locale
                                                  (locale locale)
                                                  (string (parse-locale locale))))
                              stream format-args))

;;; Locale specific strings follow.

(defstring :selected-language “Default”)

(defstring :about-page “About”
           (:|@@| “Aboutway”))

(defstring :administration-menu “Administration”
           (:|@@| “Administrationway”))

(defstring :all-rights-reserved “All rights reserved.”
           (:|@@| “Allway ightsray eservedray.”))

;; When creating a new product, suggest this value
;; as the name of the default branch.
(defstring :branch-name/initial-suggested-value “Main”
           (:|@@| “Ainmay”))

(defstring :browser-header-page “Browser Headers”
           (:|@@| “Owserbray Eadershay”))

(defstring :changesafe “ChangeSafe™”
           (:|@@| “AngechayAfesay™”))

(defstring :change-files-description “Add, Delete, or Check-out files in this workspace.”)

(defstring :change-files-option “Select Files to Change”)

(defstring :change-description “ChangeSet™ Description”
           (:|@@| “AngeSetchay Escriptionday”))

(defstring :change-name “ChangeSet™ Name”
           (:|@@| “AngeSetchay Amenay”))

(defstring :change-sets “ChangeSets™”
           (:|@@| “Angechay Etssay”))

;; If the product is released under a different name,
;; this is the thing to change.
(defstring :changesafe-product-name “ChangeSafe™”
           (:|@@| “AngechayAfesay™”))

(defstring :class-browser “Class Browser”
           (:|@@| “Assclay Owserbay”))

(defstring :class-create “Create Class”
           (:|@@| “Eatecray Assclay”))

(defstring :copyright “Copyright © 1997-2003”
           (:|@@| “Opyrightcay © 1997-2003”))

(defstring :copyright-notice “Copyright © 1997-2003 ChangeSafe, LLC,  All rights reserved.”)

(defstring :create-master “Create the master repository”
           (:|@@| “Reatecay ethay astermay epositoryray”))

(defformat :create-product-reason (product-name)
           (:en “Create the ~a product.” product-name)
           (:|@@| “Eatecray ethay ~a Oductpray.” product-name))

(defformat :create-class-reason (class-name)
           (:en “Create the ~a class.” class-name)
           (:|@@| “Eatecray ethay ~a assclay.” class-name))

(defformat :create-satellite-reason (class-name)
           (:en “Create satellite repository for the ~a class.” class-name)
           (:|@@| “Eatecray atellitesay epositoryray ethay ~a assclay.” class-name))

(defformat :create-subsystem-reason (subsystem-name)
           (:en “Create the ~a subsystem.” subsystem-name)
           (:|@@| “Eatecray ethay ~a ubsystemsay.” subsystem-name))

(defformat :create-workspace-reason (workspace-name user)
           (:en “Create workspace ~a for ~a.” workspace-name user)
           (:|@@| “Eatecray orkspaceway ~a for ~a.” workspace-name user))

(defstring :delete-change-description “Discard this ChangeSet™ and revert the workspace.”)

(defstring :delete-change-option “Delete ChangeSet™”)

(defstring :delete-workspace-description
     “Delete the files and directories on your local disk and unregister the workspace from the repository.”)

(defstring :delete-workspace-option “Delete Workspace”)

(defstring :edit-this-workspace “Edit this workspace”
           (:|@@| “Editway isthay orkspaceway”))

(defstring :goodbye “Goodbye”
        (:en-us “Y'all don't be strangers.”)
        (:en-gb “Cheerio.”)
        (:en    “See ya.”)
        (:fr «Au revoir»)
        (:es “Adios”))

(defstring :i-dont-understand
            “I don't understand.”
            (:fr «Je ne comprende pas.»))

(defstring :main-menu “Main Menu”
            (:|@@| “Ainmay Enumay”))

(defstring :master-change-description “Commit this change to the repository and promote it to the latest version.”)

(defstring :master-change-option “Master Change”
           (:|@@| “Astermay Angechay”))

(defstring :missing-template
            “Missing Template”
            (:|@@| “Issingmay Emplatetay”))

(defstring :login-button
            “Login”
            (:|@@| “Oginlay”))

(defstring :password
            “Password”
            (:zh “密码”))

(defstring :product-create “Create Product”
           (:|@@| “Eatecray Oductpray”))

(defstring :product-browser “Product Browser”
           (:|@@| “Oductpray Owserbay”))

(defstring :form-label/branch-name “Branch Name”
           (:|@@| “Anchbray Amenay”))

(defstring :form-label/product-description “Product Description”
           (:|@@| “Oductpray Escriptionday”))

(defstring :form-label/product-name “Product Name”
           (:|@@| “Oductpray Amenay”))

(defstring :regenerate-workspace-description
           “Restore missing files and directories to workspace.”)

(defstring :regenerate-workspace-option “Regenerate Workspace”
           (:|@@| “Egenerateray Orkspaceway”))

(defstring :reset-button “Clear”
            (:|@@| “Earclay”))

(defstring :show-browser-headers “Show Browser Headers”
            (:|@@| “Owshay Owserbray Eadershay”))

(defstring :show-configuration “Show Server Configuration”
            (:|@@| “Owshay Erversay Onfigurationcay”))

(defstring :shutdown “Shutdown”
           (:|@@| “Utdownshay”))

(defstring :submit-button
            “Submit”
            (:|@@| “Ubmitsay”))

(defformat :subscribe-to-subsystem-reason (product subsystem)
           (:en “Subscribe product ~s to subsystem ~s.” product subsystem)
           (:|@@| “Ubscribesay oductpray ~s ootay ubsystemsay ~s.” product subsystem))

(defstring :subsystem-create “Create Subsystem”
           (:|@@| “Eatecray Ubsystemsay”))

(defformat :query-workspace-reason (user-name id)
           (:en “Query workspace ~s for user ~s.” id user-name))

(defstring :recursive-error
           “Internal error within the error handler.  Continuing is not possible.”)

(defstring :reports “Reports”
           (:|@@| “Eportsray”))

(defstring :return-to “Return to”
           (:|@@| “Eturnray otay”))

(defstring :select-changes-description “Modify the current view by adding or removing individual ChangeSets™.”)

(defstring :select-changes-option “Add or Remove ChangeSets™”)

(defstring :server-configuration “Server Configuration”
           (:|@@| “Erversay Onfigurationcay”))

(defstring :subsystem-browser “Subsystem Browser”
           (:|@@| “Ubsystemsay Owserbay”))

(defformat :template-is-missing (uri)
           (:en “The template for ~s is missing.  Sorry.” uri)
           (:|@@| “Erewhay idday ~s ogay?” uri))

(defformat :type-error (datum expected-type)
           (:en “The value ~s, is not of expected type ~s.” datum expected-type)
           (:en-gb “Sorry to trouble you, old chap, but I was rather hoping for a ~s and I'm afraid that ~s isn't quite what I had in mind.”
            expected-type datum)
           (:fr «L'objet ~s n'est pas un ~s.» datum expected-type))

(defstring :unicode-test-page “Unicode Test Page”
            (:|@@| “Unicodeway Esttay Agepay”))

(defstring :user
            “User”
            (:|@@| “Userway”))

(defstring :username
            “Username”
            (:zh “用户”))

;; Name of vendor of this product.
(defstring :vendor
           “ChangeSafe, LLC”
           (:|@@|  “AngechayAfesay, LLC”)
           (:en-gb “ChangeSafe UK, LTD”) ;; for example
           )

(defstring :welcome
           “Welcome to”
           (:|@@| “Elcomeway otay”)
           (:fr «Bienvenue a»))

(defstring :workspace-browser “Workspace Browser”
           (:|@@| “Orkspaceway Owserbay”))

(defstring :workspace-create “Create Workspace”
           (:|@@| “Orkspaceway Eatecray”))

(defstring :workspace-description “Workspace Description”
           (:|@@| “Orkspaceway Escriptionday”))

(defstring :workspace-guid “Workspace GUID”
           (:|@@| “Orkspaceway GUID”))

(defstring :workspace-id “Workspace ID”
           (:|@@| “Orkspaceway ID”))

(defstring :workspace-info-page “Workspace Information”
           (:|@@| “Orkspaceway Informationway”))

(defstring :xml-test-page “XML Test Page”
           (:|@@| “XML Esttay Agepay”))
