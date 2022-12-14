;;; package -- Summary:
;;; Commentary:
;;; simple - debug package that can be used with lldb

;;; Code:

(require 'json)
(require 'cl-lib)
(require 'projectile)

(defface simple-debug-breakpoint-face
  '((t :distant-foreground "white"
	   :box (:line-width -1 :color "red")))
  "Face used to highlight breakpoints."
  :group 'simple-debug)

(defvar simple-debug-breakpoints-file ".simple-debug.json"
  "Breakpoints file where all the breakpoints are saved.")

(make-variable-buffer-local
 (defvar simple-debug-breakpoints-file-path nil
   "Breakpoints file path where all the breakpoints are saved."))

;; This is a hash-table containing elements of (linenumber -> function) key value pairs
(make-variable-buffer-local
 (defvar simple-debug-file-breakpoints nil
   "All the breakpoints in the current buffer."))

(defun simple-debug-create-line-hash-table (line)
  "Create a hash table for LINE."
  (let ((lhash (make-hash-table :test 'equal)))
	(puthash 'line line lhash)
	lhash))

(defun simple-debug-create-line-function-hash-table (line function)
  "Create a hash table for LINE and FUNCTION."
  (let ((lfhash (make-hash-table :test 'equal)))
	(puthash 'line line lfhash)
	(puthash 'function function lfhash)
	lfhash))

(defun simple-debug-create-empty-hash-table (filename)
  "Create an empty top level breakpoints hash-table with file = FILENAME."
  (let ((lfhash (make-hash-table :test 'equal)))
	(puthash "file" filename lfhash)
	(puthash "breakpoints" (list) lfhash)
	lfhash))

(defun simple-debug-create-empty-list (filename)
  "Create an empty top level list for all breakpoints.
With one hash-table with file = FILENAME"
  (let ((lflist (list)))
  (push (simple-debug-create-empty-hash-table filename) lflist)
	lflist))

(defun simple-debug-flush-breakpoints-list (file contents)
  "Write out CONTENTS into FILE.
File must be absolute path to file."
  (with-temp-file file
	(insert contents)))

(defun simple-debug-get-updated-breakpoints-list ()
  "Return a list with current breakpoints."
  (let ((lst ()))
	(maphash (lambda (linenumber function)
			   (if function
				   (push (simple-debug-create-line-function-hash-table linenumber function) lst)
				 (push (simple-debug-create-line-hash-table linenumber) lst)))
			 simple-debug-file-breakpoints)
	lst))

(defun simple-debug-get-breakpoints-list (file-path)
  "Read out FILE-PATH(.simple-debug.json) file and fill out a json object."
  (let* ((json-object-type 'hash-table)
		 (json-array-type 'list)
		 (json-key-type 'string))
	(json-read-file file-path)))

(defun simple-debug-get-breakpoints-list-exclusive (filename)
  "Find FILENAME in all breakpoints."
  (let ((all-breakpoints (simple-debug-get-breakpoints-list simple-debug-breakpoints-file-path))
		(exclusive-breakpoints (list)))
	(if all-breakpoints
		(dolist (breakpoints all-breakpoints)
		  (let ((file (gethash "file" breakpoints)))
			(if (not (string= filename file))
				(push breakpoints exclusive-breakpoints)))))
	exclusive-breakpoints))

(defun simple-debug-refresh-breakpoints-file ()
  "Write out updated breakpoints status into .simple-debug.json."
  (let ((updated-breakpoints (simple-debug-get-updated-breakpoints-list))
		(json-breakpoints (simple-debug-create-empty-hash-table (buffer-file-name)))
		(all-breakpoints (simple-debug-get-breakpoints-list-exclusive (buffer-file-name))))
	(progn
	  (puthash "breakpoints" updated-breakpoints json-breakpoints)
	  (push json-breakpoints all-breakpoints)
	  (let ((json-encoding-pretty-print t))                ;; To make sure json-encode prints pretty for this package (buffer)
		(simple-debug-flush-breakpoints-list simple-debug-breakpoints-file-path (json-encode all-breakpoints))))))

(defun simple-debug-save-remove-breakpoint (overlay linenumber function)
  "Save simple-debug breakpoint in the current buffer.
Breakpoint is an object of OVERLAY and its LINENUMBER plus FUNCTION."
  (if overlay
	  (puthash linenumber function simple-debug-file-breakpoints)
	(remhash linenumber simple-debug-file-breakpoints)))

;; Source https://stackoverflow.com/questions/14454219/how-to-highlight-a-particular-line-in-emacs
(defun simple-debug-find-overlays-specification (prop pos)
  "Check for overlays at the POS and return true if found.
Only checks for overlays with PROP."
  (let ((overlays (overlays-at pos))
		found)
	(while overlays
	  (let ((overlay (car overlays)))
		(if (overlay-get overlay prop)
			(setq found (cons overlay found))))
	  (setq overlays (cdr overlays)))
	found))

(defun simple-debug-toggle-line-highlights (startpos endpos)
  "Toggle a visual breakpoint at location STARTPOS to ENDPOS line."
  (if (simple-debug-find-overlays-specification 'line-highlight-overlay-marker startpos)
	  (remove-overlays startpos endpos)
	(let ((overlay-highlight (make-overlay startpos endpos)))
	  (overlay-put overlay-highlight 'face 'simple-debug-breakpoint-face)
	  (overlay-put overlay-highlight 'before-string (propertize "x" 'display (list 'left-fringe 'filled-rectangle 'warning)))
	  (overlay-put overlay-highlight 'line-highlight-overlay-marker t)
	  overlay-highlight)))

(defun simple-debug-toggle-breakpoint (line function)
  "Toggle a breakpoint at line LINE or if FUNCTION is not nill at the FUNCTION on line LINE."
  (save-excursion
	(goto-char (point-min))
	(forward-line (1- line))
	(let* ((startpos (line-beginning-position))
		  (endpos (line-end-position)))
	  (progn
		(if function
			(let* ((found_index (string-match-p (regexp-quote function) (thing-at-point 'line t))))
			  (if found_index
				  (progn
					(setq startpos (+ startpos found_index))
					(setq endpos (+ startpos (length function)))))))
		(let* ((debug-overlay (simple-debug-toggle-line-highlights startpos endpos)))
		  (simple-debug-save-remove-breakpoint debug-overlay line function))))))

(defun simple-debug-find-file-breakpoints (filename)
  "Find FILENAME in all breakpoints."
  (let ((all-breakpoints (simple-debug-get-breakpoints-list simple-debug-breakpoints-file-path))
		(json-breakpoints nil))
	(if all-breakpoints
		(dolist (breakpoints all-breakpoints)
		  (let ((file (gethash "file" breakpoints)))
			(if (string= filename file)
				(setq json-breakpoints breakpoints)))))
	json-breakpoints))

(defun simple-debug-load-file-breakpoints (filename)
  "Load all breakpoints for FILENAME from .simple-debug.json file."
  (progn
	(let* ((json-breakpoints (simple-debug-find-file-breakpoints filename)))
	  (if json-breakpoints
		  (let ((bpoints (gethash "breakpoints" json-breakpoints)))
			(if bpoints
				(dolist (bpoint bpoints)
				  (let ((l (gethash "line" bpoint))
						(f (gethash "function" bpoint)))
					(simple-debug-toggle-breakpoint l f)))))))))

(defun simple-debug-find-breakpoints-file ()
"Find simple-debug-breakpoints-file(.simple-debug.json) in projectile root.
If we can't find it, we will create one.
And set the global simple-debug-breakpoint-file-path variable pointing to it."
(let ((filename (concat (file-name-as-directory (projectile-project-root)) simple-debug-breakpoints-file)))
  (progn
	(setq simple-debug-file-breakpoints (make-hash-table :test 'equal))
	(setq simple-debug-breakpoints-file-path filename)
	(if (not (file-exists-p filename))
		(simple-debug-flush-breakpoints-list filename "[]"))
	(simple-debug-load-file-breakpoints (buffer-file-name)))))

(defun simple-debug-toggle-line-breakpoint ()
  "Toggle a breakpoint on current line."
  (interactive)
  (let ((line (line-number-at-pos)))
	(progn
	  (simple-debug-toggle-breakpoint line nil)
	  (simple-debug-refresh-breakpoints-file))))

(defun simple-debug-toggle-function-breakpoint ()
  "Toggle a breakpoint on current function."
  (interactive)
  (let ((line (line-number-at-pos))
		(function (buffer-substring (region-beginning) (region-end))))
	(progn
	  (simple-debug-toggle-breakpoint line function)
	  (simple-debug-refresh-breakpoints-file))))

;; From https://nullprogram.com/blog/2013/02/06/
;;;###autoload
(define-minor-mode simple-debug
  "Defines simple-debug minor mode."
  :lighter " SiD"
  :keymap (let ((map (make-sparse-keymap)))
			(define-key map (kbd "<f6>") 'simple-debug-toggle-line-breakpoint)
			(define-key map (kbd "<f7>") 'simple-debug-toggle-function-breakpoint)
			map)
  (simple-debug-find-breakpoints-file))

;;;###autoload
(add-hook 'c-mode-common-hook 'simple-debug)

(provide 'simple-debug)
;;; simple-debug.el ends here
