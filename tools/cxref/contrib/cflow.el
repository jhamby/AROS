;;; CFLOW.EL --- C flow graph 

;; Copyright (C) 1997 Paul Barham

;; Author: Paul Barham Paul.Barham@cl.cam.ac.uk
;; Maintainer: Paul Barham Paul.Barham@cl.cam.ac.uk
;; Created: 19 Mar 1997
;; Version: 1.0
;; Keywords: C language cxref flow static call graph browser

 
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 1, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; A copy of the GNU General Public License can be obtained from this
;; program's author (send electronic mail to Paul.Barham@cl.cam.ac.uk)
;; or from the Free Software Foundation, Inc., 675 Mass Ave,
;; Cambridge, MA 02139, USA.

;; LCD Archive Entry:
;; cflow|Paul Barham|Paul.Barham@cl.cam.ac.uk
;; |C flow graph 
;; |$Date$|$Revision$|~/packages/cflow.el

;;; Commentary:

;; This package is intended to be used in conjunction with cxref
;; packeage (http://www.gedanken.demon.co.uk/cxref/index.html)

;; It parses the cxref.function file generated by cxref and fires up 
;; a sort of folding mode which allows the hierarchical flow graph
;; to be recursively expanded.  
;;
;; Simply find the file cxref.function in a buffer and type M-x cflow
;;
;; Then you can use:
;;
;; SPC or RETURN   Expand the current line
;; x               Close up the flow graph under the current node
;; .               Find the function on the current line in another window
;; q               Quit
;;

;;; Change log:
;; $Log$
;; Revision 1.2  2004/01/04 19:43:16  galaxy
;; *** empty log message ***
;;

;;; Variables:

(defvar cflow-filenames t 
  "Show filenames where each function is declared")

(defvar cflow-main "main" 
  "The name of the function at the root of the flowgraph")

(defvar cflow-indent "|   " 
  "The indentation string added per-level of the flowgraph")

;;; Code:

;;;
;;; This reads in the output of cxref 
;;;
(defun cxref-readline ()
  (interactive)
  (let (file fn scope refs 
	(eol (progn (end-of-line) (point))))
    (beginning-of-line)
    (re-search-forward "\\([^ \t]+\\)[ \t]*" eol t) 
    (setq file (buffer-substring-no-properties 
		(match-beginning 1) (match-end 1)))
    (re-search-forward "\\([^ \t]+\\)[ \t]*" eol t) 
    (setq fn   (buffer-substring-no-properties 
		(match-beginning 1) (match-end 1)))
    (re-search-forward "\\([0-9]+\\)[ \t]*" eol t) 
    (setq scope (car (read-from-string
		      (buffer-substring-no-properties 
		       (match-beginning 1) (match-end 1)))))
    (setq refs nil)
    (while (re-search-forward "\\([^ \t]+\\)[ \t]*" eol t) 
      (setq refs (cons (buffer-substring-no-properties 
			(match-beginning 1) (match-end 1)) refs)))
    (list fn file scope (nreverse refs))
  ))

(defun cxref-parse ()
  (interactive)
  (let (fns)
    (save-excursion 
      (beginning-of-buffer)
      (while (< (point) (point-max))
	(setq fns (cons (cxref-readline) fns))
	(forward-line 1))
      )
    fns)
)

(defun cflow-insert (indent fname)
  (string-match "[&%]*\\(.*\\)" fname)
  (let* ((basename (substring fname (match-beginning 1)))
	 (fun (assoc basename cflow-fns)))
    (if fun 
	(insert (concat indent 
			fname
			(if cflow-filenames
			    (concat " (" (nth 1 fun) ")")
			  "")
			"\n"))
      (insert (concat indent fname "\n")))
    ))
  
(defun cflow-expand ()
  "Expand this node in the flow graph"
  (interactive)
  (let (name indent fun)
    (save-excursion
      (beginning-of-line)
      (re-search-forward "\\(^[| ]*\\)[&%]*\\([*a-zA-Z0-9_$]+\\)")
      (setq indent (concat (buffer-substring-no-properties 
			     (match-beginning 1)
			     (match-end 1)) cflow-indent))
      (setq name (buffer-substring-no-properties 
		 (match-beginning 2)
		 (match-end 2)))
      (setq fun (assoc name cflow-fns))
      (forward-line 1)
      (beginning-of-line)
      (or (looking-at indent)
	  (mapcar (lambda (fname) 
		    (cflow-insert indent fname))
		  (nth 3 fun)))

      ))
)
(defun cflow-contract ()
  "Close up this section of the flow graph"
  (interactive)
  (let (name indent fun)
    (save-excursion
      (beginning-of-line)
      (re-search-forward "\\(^[| ]*\\)")
      (setq indent (concat (buffer-substring-no-properties 
			     (match-beginning 1)
			     (match-end 1)) cflow-indent))
      (forward-line 1)
      (beginning-of-line)
      (while (looking-at indent)
	(kill-line 1))
      ))
)  

(defun cflow-tag ()
  "Find the function on the current line using TAGS"
  (interactive)
  (let (name indent fun)
    (save-excursion
      (beginning-of-line)
      (re-search-forward "\\(^[| ]*\\)[&%]*\\([*a-zA-Z0-9_$]+\\)")
      (setq indent (concat (buffer-substring-no-properties 
			     (match-beginning 1)
			     (match-end 1)) cflow-indent))
      (setq name (buffer-substring-no-properties 
		 (match-beginning 2)
		 (match-end 2)))
      (message "Finding %s" name)
      (find-tag-other-window name)))
)

(define-derived-mode cflow-mode fundamental-mode "CFlow"
  (setq cflow-mode t)
  ;; Linemenu simply highlights the current line
  ;  (linemenu-initialize) 
)

(define-key cflow-mode-map " " 'cflow-expand)    
(define-key cflow-mode-map "" 'cflow-expand)  
(define-key cflow-mode-map "x" 'cflow-contract)    
(define-key cflow-mode-map "." 'cflow-tag)    
(define-key cflow-mode-map "q" 'bury-buffer)    

(defun cflow ()
  (interactive)
  (let ((buf (get-buffer-create "*cflow*")))
    (setq cflow-fns (cxref-parse))
    (switch-to-buffer buf)
    (cflow-mode)
    (erase-buffer)
    ;; Don't understand this :-)
    ; (make-local-variable 'cflow-fns)
    (cflow-insert "" "$")
    (cflow-insert "" cflow-main))
)

;;; CFLOW.EL ends here
