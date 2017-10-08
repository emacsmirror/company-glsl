;;; company-glsl.el --- Support glsl in company-mode

;; Copyright (C) 2015 Väinö Järvelä <vaino@jarve.la>
;;
;; Author: Väinö Järvelä <vaino@jarve.la>
;; Created: 11 January 2015
;; Version: 0.5
;; Package-Requires: ((company "0.8.7"))

;;; License:
;; This file is not part of GNU Emacs.
;; However, it is distributed under the same license.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; Provides glsl completion by using glslangValidator.
;; glslangValidator can be found from:
;;   https://www.khronos.org/opengles/sdk/tools/Reference-Compiler/

;; To use this package with company-mode run;
;;   (add-to-list 'company-backends 'company-glsl)

;; To use this package, you must be in glsl major mode.

;; This package is still quite incomplete, but it does basic symbol
;; completion.  It finds all the symbols that are referenced in the
;; code or references by the linker.  It can also reference function
;; names, but at the moment no other information is retained.

;; There is also no scoping, so completion candidates includes all
;; symbols, even if they are not available in the current scope.  Even
;; any function parameters are seen as candidates in all other
;; functions.

;; TODO: Do a better single pass parser which properly detects
;;       functions and only symbols assigned to.

;; TODO: Symbol scope

;;; Code:

(require 'cl-lib)
(require 'company)
(require 'glsl-mode)

(defun company-glsl--is-anon (symbol)
  "Check if the given SYMBOL is prefixed with `anon@'."
  (string-prefix-p "anon@" symbol))

(defun company-glsl--has-block (type)
  "Check if the given TYPE is sourrounded by `block{}'."
  (string-match-p "block{" type))

(defun company-glsl--propertize (symbol type linenum)
  "Propertize a given SYMBOL with a TYPE and LINENUM."
  (propertize
   symbol
   'meta type
   'linenum linenum))

(defun company-glsl--parse-block (block linenum &optional parent)
  "Parse a BLOCK from line number LINENUM and optional argument PARENT."
  (with-temp-buffer
    (insert block)
    (goto-char (point-min))
    (re-search-forward "{" nil t)
    (cl-loop while
             (re-search-forward " ?\\([^,]+\\) \\([^,]+\\)[,}]" nil t)
             collect
             (company-glsl--propertize
              (if parent
                  (concat parent "." (match-string 2))
                (match-string 2))
              (match-string 1)
              linenum))))

(defun company-glsl--parse-match (symbol type linenum)
  "Parse a SYMBOL with TYPE and its line number LINENUM."
  (if (company-glsl--is-anon symbol)
      (company-glsl--parse-block type linenum)
    (if (company-glsl--has-block type)
        (cons (company-glsl--propertize symbol type linenum)
              (company-glsl--parse-block type linenum symbol))
      (list (company-glsl--propertize symbol type linenum)))))

(defun company-glsl--parse-func (funcname linenum)
  "Propertize a function with FUNCNAME with it's line number LINENUM."
  (company-glsl--propertize funcname "function" linenum))

(defun company-glsl--get-types (filename)
  "Get GLSL types from calling glslangValidator on FILENAME."
  (with-temp-buffer
    (call-process "glslangValidator" nil (list (current-buffer) nil) nil "-i" filename)
    (goto-char (point-min))
    (let ((vars
           (cl-reduce
            'append
            (cl-loop while
                     (re-search-forward "^.*:\\([0-9?]+\\) +'\\(.*\\)' \\(.*\\)$" nil t)
                     collect
                     (company-glsl--parse-match (match-string 2) (match-string 3) (match-string 1)))))
          (funcs
           (progn
             (goto-char (point-min))
             (cl-loop while
                      (re-search-forward "^.*:\\([0-9?]+\\) +Function Definition: \\([a-zA-Z0-9_]+\\)(" nil t)
                      collect
                      (company-glsl--parse-func (match-string 2) (match-string 1))))))
      (append funcs vars))))

(defun company-glsl--fuzzy-match-prefix (prefix candidate)
  (cl-subsetp (string-to-list prefix)
              (string-to-list candidate)))

(defun company-glsl--match-prefix (prefix candidate)
  (string-prefix-p prefix candidate))


(defun company-glsl--property-linenum (prop)
  (let ((linenum (get-text-property 0 'linenum prop)))
    (if (eq linenum "?")
        0
      (string-to-number linenum))))

(defun company-glsl--candidate-sorter (x y)
  "Sort parsed candidates X and Y by lineums."
  (if (string= x y)
      (< (company-glsl--property-linenum x) (company-glsl--property-linenum y))
    (string< x y)))

(defun company-glsl--candidates (arg)
 "Provide candidates pased on the prefix command ARG by parsing."
  (cl-stable-sort
   (cl-remove-if-not
    (lambda (c) (company-glsl--match-prefix arg c))
    (company-glsl--get-types buffer-file-name))
   'company-glsl--candidate-sorter))

(defun company-glsl--location (arg)
  (let ((linenum (get-text-property 0 'linenum arg)))
    (if (not (eq "?" linenum))
        (cons buffer-file-name (string-to-number linenum))
      (cons buffer-file-name 0))))

(defun company-glsl--extended-candidates (arg)
  "Extends parsed candidates based on ARG with type/modifier/builtin lists as provided by glsl-mode."
  (append (company-glsl--candidates arg)
          glsl-type-list
          glsl-modifier-list
          glsl-deprecated-modifier-list
          glsl-builtin-list
          glsl-deprecated-builtin-list))

(defun company-glsl (command &optional arg &rest ignored)
  "Provide GLSL completion info according to prefix COMMAND and ARG.  IGNORED is not used."
  (interactive (list 'interactive))
  (cl-case command
    (interactive (company-begin-backend 'company-glsl))
    (prefix (and (eq major-mode 'glsl-mode)
                 buffer-file-name
                 (or (company-grab-symbol-cons "\\." 1)
                     'stop)))
    (candidates (company-glsl--extended-candidates arg))
    (sorted t)
    (duplicates t)
    (meta (get-text-property 0 'meta arg))
    (annotation (concat " " (get-text-property 0 'meta arg)))
    (location (company-glsl--location arg))))

(provide 'company-glsl)
;;; company-glsl.el ends here
