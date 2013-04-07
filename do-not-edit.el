;;; do-not-edit.el --- read-only buffer for generated files

;; Copyright 2009, 2010, 2011, 2012, 2013 Kevin Ryde
;;
;; Author: Kevin Ryde <user42@zip.com.au>
;; Version: 10
;; Keywords: convenience, read-only
;; URL: http://user42.tuxfamily.org/do-not-edit/index.html
;; EmacsWiki: CategoryFiles
;;
;; do-not-edit.el is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the
;; Free Software Foundation; either version 3, or (at your option) any later
;; version.
;;
;; do-not-edit.el is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
;; Public License for more details.
;;
;; You can get a copy of the GNU General Public License online at
;; <http://www.gnu.org/licenses/>.


;;; Commentary:

;; This spot of code makes a buffer read-only if it contains "DO NOT EDIT"
;; or "DO NOT MODIFY", to keep you from accidentally editing generated
;; files.  See the `do-not-edit-readonly' docstring below for more.

;;; Emacsen:

;; Designed for Emacs 21 up, works in XEmacs 21 and Emacs 20.

;;; Install:

;; Put do-not-edit.el in one of your `load-path' directories, and in
;; your .emacs add
;;
;;     (autoload 'do-not-edit-readonly "do-not-edit")
;;     (add-to-list 'find-file-hooks 'do-not-edit-readonly)
;;
;; There's an autoload cookie below for the function, if you know how to use
;; `update-file-autoloads' and friends; then just customize or add to
;; find-file-hooks.

;;; History:

;; Version 1 - the first version
;; Version 2 - more "Don't edit"s
;; Version 3 - add ppport.h form
;; Version 4 - add emacs autoload-rubric and a mozilla form
;; Version 5 - new `do-not-edit-perl-blib'
;; Version 6 - add perl AutoSplit form
;;           - do nothing if already readonly
;; Version 7 - avoid xemacs21 file-truename error on file vs directory
;; Version 8 - add Xatom.h form
;; Version 9 - add imake
;; Version 10 - add Date::Manip::TZ

;;; Code:

(defconst do-not-edit-regexp
  (eval-when-compile
    (concat
     ;; Emacs loaddefs etc, per `autoload-rubric' function
     ;; Only when file starts with this form.
     ;;               v--match 1
     "\\`;;; .* --- \\(automatically extracted\\)"  ;; <-- match 1

     ;; Perl AutoSplit.pm
     ;; This string appears in the AutoSplit.pm file itself, but past the
     ;; first 25 lines so doesn't get caught.
     "\\|"                                  ;; v-- match 2
     "^# Changes made here will be lost when \\(autosplit\\) is run again"

     ;; X11 Xatoms.h and X server source initatoms.c
     ;; except not with \ following, so as not to pick up "buildatoms" script
     "\\|"
     "THIS IS A GENERATED FILE[^\\]"

     "\\|\\b"
     (regexp-opt '("DO NOT EDIT"
                   "DO NOT MODIFY"
                   "Don't edit this file"  ;; Perl ExtUtils::MakeMaker
                   "Do not edit this file" ;; Perl ExtUtils::ParseXS
                   "Do NOT edit this file" ;; Perl Devel::PPPort
                   "Do not edit."          ;; various mozilla
                   "do not edit!"          ;; imake Makefile
                   "This file was automatically generated." ;; Date::Manip::TZ
                   ))))

  "Pattern used by `do-not-edit-readonly'.
This is an internal part of do-not-edit.el.  Normally the whole
of the regexp match is displayed in the do-not-edit message as
the reason for read-only, but the first couple of \\(..\\) groups
are short special cases to display less than the whole.")

;;;###autoload
(defun do-not-edit-readonly ()
  "Set buffer read-only if it says DO NOT EDIT.
This function is designed for use from `find-file-hook'.

It keeps you from editing generated files etc which announce
themselves near the start of the buffer as variously

   DO NOT EDIT
   DO NOT MODIFY
   Don't edit this file        (Perl ExtUtils::MakeMaker)
   Do not edit this file       (Perl ExtUtils::ParseXS, ~/.xdvirc)
   Do NOT edit this file       (Perl Devel::PPPort)
   Do not edit.                (various mozilla)
   do not edit!                (imake)
   automatically extracted     (Emacs `autoload-rubric')
   autosplit run               (Perl AutoSplit.pm)
   THIS IS A GENERATED FILE    (X11 Xatom.h)
   This file was automatically generated  (Date::Manip::TZ)

If you really do want to edit you can always `\\[toggle-read-only]'
\(`toggle-read-only') in the usual way.

It also works to simply remove \"w\" write permission from
generated files.  Emacs automatically makes the buffer read-only
if the file is read-only.  But perms can be annoying when they
make \"rm -i\" etc query about removing; and code generating the
file may have to know to set writable/unwritable when updating.

`do-not-edit-readonly' can be bad for lisp code which updates a
generated file by visiting it with a plain `find-file'.  If
`do-not-edit-readonly' sets the buffer read-only then the code
will probably throw an error.  Initial file creation is fine, but
an update of something with a DO NOT EDIT in it fails.

The do-not-edit.el home page is
URL `http://user42.tuxfamily.org/do-not-edit/index.html'"

  (unless buffer-read-only
    (save-excursion
      (goto-char (point-min))
      (let ((case-fold-search nil))
        (when (re-search-forward do-not-edit-regexp
                                 (save-excursion (forward-line 25) (point))
                                 t)
          (message "Read-only due to %S" (or (match-string 1)
                                             (match-string 2)
                                             (match-string 0)))
          (setq buffer-read-only t))))))

;;;###autoload
(defun do-not-edit-perl-blib ()
  "If the buffer file is under a Perl \"blib\" dir then set read-only.
This function is designed for use from `find-file-hook'.

It keeps you from editing files under an ExtUtils::MakeMaker
/blib directory.  The files there are copies from the working
directory and will be overwritten by the next \"make\" or removed
by \"make clean\".

`buffer-file-name' is checked (when not nil) for \"/blib/\".
`file-truename' is applied so as to notice filenames elsewhere
which are symlinks into a blib dir, or names in a blib which are
symlinks pointing to an actual file elsewhere.

If you really want to edit a blib file you can always `\\[toggle-read-only]'
\(`toggle-read-only') in the usual way."

  ;; xemacs 21.4.22 `file-truename' throws an error if /foo/bar/quux has
  ;; "foo" or "bar" files instead of directories.  Better the emacs way of
  ;; quietly allowing that, but for now trap and use the plain name.
  ;;
  (unless buffer-read-only
    (when (and buffer-file-name
               (let ((case-fold-search nil))
                 (string-match "/blib/"
                               (condition-case nil
                                   (file-truename buffer-file-name)
                                 (error buffer-file-name)))))
      (setq buffer-read-only t)
      (message "Read-only under Perl blib"))))

;; emacs  21 - find-file-hooks is a defvar
;; xemacs 21 - find-file-hooks is a defcustom, give custom-add-option
;; emacs  22 - find-file-hooks becomes an alias for find-file-hook, and the
;;             latter is a defcustom, give custom-add-option on that
;;
;;;###autoload
(if (eval-when-compile (boundp 'find-file-hook))
    (progn
      ;; emacs22
      (custom-add-option 'find-file-hook 'do-not-edit-readonly)
      (custom-add-option 'find-file-hook 'do-not-edit-perl-blib))
  ;; xemacs21
  (custom-add-option 'find-file-hooks 'do-not-edit-readonly)
  (custom-add-option 'find-file-hooks 'do-not-edit-perl-blib))

;; LocalWords: ExtUtils MakeMaker ParseXS Devel PPPort mozilla autosplit AutoSplit blib Xatom symlinks docstring unwritable dir filenames el

(provide 'do-not-edit)

;;; do-not-edit.el ends here
