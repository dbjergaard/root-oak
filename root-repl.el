(require 'comint)
(defgroup root-inferior nil
  "Running ROOT from Emacs."
  :group 'root)
(defcustom *root-hist* nil
  "Path to Inferior ROOT history file, if nil defaults to \"~/.root_hist\"")
(defcustom *root-sys* (getenv "ROOTSYS")
  "Directory where root lives"
  :type 'string
  :group 'root-inferior)
(defcustom *root-bin* (concat *root-sys* "/bin/root")
  "Path to root binary"
  :type 'string
  :group 'root-inferior)
(defcustom *root-args* ""
  "User defined arguments to get passed to root when the daemon
  is started. '-l' is automatically passed." 
  :type 'string
  :group 'root-inferior)
(defcustom *inf-root-prompt*  "\\(^root\s-\[[0-9]+\]\\)"
  "Regexp for ROOT prompt"
  :type 'regexp
  :group 'root-inferior)
(defcustom inferior-root-buffer "*ROOT repl*"
  "Name of buffer for running an inferior ROOT process."
  :type 'string
  :group 'root-inferior)

;; This code is inspired by octave-inf.el
(defun inferior-root (arg)
  "Start an inferior ROOT process, buffer is put into root-repl-mode.
  
Unless ARG is non-nil, switch to this buffer."
  (interactive "P")
  (let ((buffer inferior-root-buffer))
    (get-buffer-create buffer)
    (if (comint-check-proc buffer)
	nil
      (with-current-buffer buffer
	(comint-mode)
	(inferior-root-startup)
	(inferior-root-mode)))
    (unless arg
      (pop-to-buffer buffer))))
;;;###autoload
(defalias 'run-root 'inferior-root)

(defun inferior-root-startup ()
  "Start the inferior ROOT process."
  (let ((proc (comint-exec-1 (substring inferior-root-buffer 1 -1)
			   inferior-root-buffer
			   *root-bin*
			   (append (list "-l" *root-args*)))))
    (set-process-filter proc 'inferior-root-output-digest)
    (setq comint-ptyp process-connection-type
	  inferior-root-process proc)
    (goto-char (point-max))
    (set-marker (process-mark proc) (point))
    (set-process-filter proc 'inferior-root-output-filter)
    (run-hooks 'inferior-root-startup-hook)))

(defun inferior-root-output-filter (proc string)
  "Taken from Octave mode, ring Emacs bell if output starts with
  ASCII bell, pass the rest to `comint-output-filter'."
  (comint-output-filter proc (inferior-root-strip-ctrl-g string)))
(defun inferior-root-strip-ctrl-g (string)
  "Strip ctrl-g from begining of string"
  (when (string-match "^\a" string)
    (ding)
    (setq string (substring string 1))) 
  string)
(defun root-output-filter (output)
  "Filter output from the ROOT process"
  (let ((sani-output (cdr (split-string (ansi-color-filter-apply output) "\n"))))
    ;(message "%s" sani-output)
    (if sani-output
    	(mapconcat 'identity sani-output "\n")
      " ")
    ))

(define-derived-mode inferior-root-mode comint-mode "root-repl"
  "Major mode for interacting with an inferior ROOT process.

Entry to this mode successively runs the hooks `comint-mode-hook'
and `inferior-root-mode-hook'."

  (make-local-variable 'comint-prompt-read-only)
  (setq comint-prompt-regexp *inf-root-prompt*
	mode-line-process '(":%s")
	comint-prompt-read-only t)
  (set-syntax-table c++-mode-syntax-table)
  (set (make-local-variable 'font-lock-multiline) t)
  (c-basic-common-init)
  (c-font-lock-init)
  (ansi-color-for-comint-mode-filter)
  (setq local-abbrev-table c++-mode-abbrev-table
  	abbrev-mode t)
  (use-local-map c++-mode-map)
  (add-hook 'comint-preoutput-filter-functions 'root-output-filter)
  (setq comint-input-ring-file-name
	(or *root-hist* "~/.root_hist")
	comint-input-ring-size 1024)
  (comint-read-input-ring t))