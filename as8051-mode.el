;;; as8051-mode.el --- ASXXXX 8051 assembly major mode -*- lexical-binding: t; -*-

;; This is free and unencumbered software released into the public domain.

;; Author: webx007
;; URL: https://github.com/webx007/as8051-mode
;; Version: 1.0.0
;; Package-Requires: ((emacs "28.1"))

;; Adapted/copied from nasm-mode 
;;  Author: Christopher Wellons <wellons@nullprogram.com>
;;  URL: https://github.com/skeeto/nasm-mode

;;; Commentary:

;; A major mode for editing ASXXXX assembly code for the 8051 (Intel MCS-51) microprocessors.
;; It provides:
;; - syntax highlighting
;; - automatic indentation
;; - imenu integration
;; - support for 8051 instructions and registers
;; - support for ASXXXX syntax

;; ASXXXX Cross assembler: https://shop-pdp.net/ashtml/

;; The keyword lists are up to date as of ASXXXX 5.40
;; https://shop-pdp.net/ashtml/as8051.htm

;;; Code:

(require 'imenu)

(defgroup as8051-mode ()
  "Options for `as8051-mode'."
  :group 'languages)

(defgroup as8051-mode-faces ()
  "Faces used by `as8051-mode'."
  :group 'as8051-mode)

(defcustom as8051-basic-offset (default-value 'tab-width)
  "Indentation level for `as8051-mode'."
  :type 'integer
  :group 'as8051-mode)

(defcustom as8051-after-mnemonic-whitespace :tab
  "In `as8051-mode', determines the whitespace to use after mnemonics.
This can be :tab, :space, or nil (do nothing)."
  :type '(choice (const :tab) (const :space) (const nil))
  :group 'as8051-mode)

(defface as8051-registers
  '((t :inherit (font-lock-variable-name-face)))
  "Face for registers."
  :group 'as8051-mode-faces)

(defface as8051-sfr-bits
  '((t :inherit (font-lock-variable-name-face)))
  "Face for SFR bit flags."
  :group 'as8051-mode-faces)


(defface as8051-prefix
  '((t :inherit (font-lock-builtin-face)))
  "Face for prefix."
  :group 'as8051-mode-faces)

(defface as8051-types
  '((t :inherit (font-lock-type-face)))
  "Face for types."
  :group 'as8051-mode-faces)

(defface as8051-instructions
  '((t :inherit (font-lock-builtin-face)))
  "Face for instructions."
  :group 'as8051-mode-faces)

(defface as8051-directives
  '((t :inherit (font-lock-keyword-face)))
  "Face for directives."
  :group 'as8051-mode-faces)

(defface as8051-preprocessor
  '((t :inherit (font-lock-preprocessor-face)))
  "Face for preprocessor directives."
  :group 'as8051-mode-faces)

(defface as8051-labels
  '((t :inherit (font-lock-function-name-face)))
  "Face for nonlocal labels."
  :group 'as8051-mode-faces)

(defface as8051-local-labels
  '((t :inherit (font-lock-function-name-face)))
  "Face for local labels."
  :group 'as8051-mode-faces)

(defface as8051-section-name
  '((t :inherit (font-lock-type-face)))
  "Face for section name face."
  :group 'as8051-mode-faces)

(defface as8051-constant
  '((t :inherit (font-lock-constant-face)))
  "Face for constant."
  :group 'as8051-mode-faces)

(eval-and-compile
  (defconst as8051-registers
    '("R1" "R2" "R3" "R4" "R5" "R6" "R7" "ACC" "A" "B" "DPH" "DPL" "DPTR" "IE" "IP" "P0" "P1" "P2" "P3" "PC" "PCON" "PSW" "RCAP2L" "RCAP2H" "SBUF" "SCON" "SP" "T2CON" "TCON" "TH0" "TH1" "TH2" "TL0" "TL1" "TL2" "TMOD" )
    "8051 registers for `as8051-mode'."))

(eval-and-compile
  (defconst as8051-directives
    '(".16bit" ".24bit" ".32bit" ".3byte" ".4byte" ".area" ".ascii" ".ascis" ".asciz" ".assume" ".bank" ".blk3" ".blk4" ".blkb" ".blkw" ".bndry" ".byte" ".db" ".define" ".ds" ".dw" ".end" ".equ" ".error" ".even" ".fcb" ".fcc"  ".fdb" ".gblequ" ".globl" ".hilo" ".incbin" ".include"  ".lclequ" ".local" ".lohi"  ".list" ".module" ".msb" ".msg" ".nlist"  ".odd" ".org" ".page" ".quad" ".radix" ".rmb" ".rs" ".sbttl" ".setdp" ".str" ".strs" ".strz" ".title" ".triple" ".undefine" ".word")
    "ASXXXX directives for `as8051-mode'."))

(eval-and-compile
  (defconst as8051-instructions
    '(
      ;; Addition/subtraction
      "add" "subb" "addc"
      ;; Multiplication/division
      "mul" "div" "dec" "inc"
      ;; Bitwise operations
      "anl" "clr" "cpl" "orl" "setb" "xrl"
      ;; Shifts
      "asr" "rl" "rlc" "rr" "rlc"
      ;; Move data
      "mov" "movc" "movx"
      ;; Jumps
      "ajmp" "ejmp" "ljmp" "jmp" "sjmp"
      ;; Comparisons/branch
      "cjne" "djnz"  "jb" "jbc" "jc" "jnb" "jnc" "jnz" "jz"
      ;; Subroutines
      "acall" "ecall" "lcall"
      ;; return
      "eret" "ret" "reti"
      ;; stack
      "pop" "push"
      ;; Exception / Interrupt
      "break"
      ;; Other
      "nop" "swap" "xch" "xchd"
      ;; Extended
      "asr" "da" "lsl" "mac")
    "8051 instructions for `as8051-mode'."))

(eval-and-compile
  (defconst as8051-types
    '("m_assign_var" "m_assign_var_v" "m_assign_var_16b" "m_assign_var_16b_v" "m_else"  "m_if_var" "m__val_ge" "m__val_le" "m_inc_file"  "m_init_zero" "m_init_zero_w" "m_io_input" "m_io_output" "m_led_on" "m_led_off" "m_msg" "m_var" "m_var_bit" "m_var_w")
    "ASXXXX Macros from utils.asm `as8051-mode'."))

(eval-and-compile
  (defconst as8051-prefix
    '()
    "not used"))

(eval-and-compile
  (defconst as8051-sfr-bits
    '("AC" "C" "CY" "EA" "ES" "ET0" "ET1" "ET2" "EX0" "EX1" "F0" "IE0" "IE1" "INT0" "INT1" "IT0" "IT1" "OV" "P" "PS" "PT0" "PT1" "PT2" "PX0" "PX1" "RB8" "REN" "RI" "RS0" "RS1" "RXD" "SM0" "SM1" "SM2" "TB8" "TF0" "TF1" "TI" "TR0" "TR1" "TXD")
    "8051/2 SFR control bits for `as8051-mode'."))

(eval-and-compile
  (defconst as8051-pp-directives
    '(".else" ".endif" ".endm" ".if" ".ifdef" ".ifdif" ".ifeq" ".iff" ".ifge" ".ifidn" ".ifle" ".iflt" ".ifnb" ".ifndef" ".ift" ".iftf" ".irp" ".irpc" ".macro" ".mdelete" ".mexit" ".narg" ".nchr" ".ntyp" ".nval" ".rept")
    "ASXXXX preprocessor directives for `as8051-mode'."))

(defconst as8051-nonlocal-label-rexexp
  "\\(\\_<[a-zA-Z_?][a-zA-Z0-9_$#@~?]*\\_>\\)\\s-*:"
  "Regexp for `as8051-mode' for matching nonlocal labels.")

(defconst as8051-local-label-regexp
  "\\(\\_<\\.[a-zA-Z_?][a-zA-Z0-9_$#@~?]*\\_>\\)\\(?:\\s-*:\\)?"
  "Regexp for `as8051-mode' for matching local labels.")

(defconst as8051-label-regexp
  (concat as8051-nonlocal-label-rexexp "\\|" as8051-local-label-regexp)
  "Regexp for `as8051-mode' for matching labels.")

;; (defconst as8051-constant-regexp
;;   "\\<$?[-+]?[0-9][-+_0-9A-Fa-fHhXxDdTtQqOoBbYyeE.]*\\>"
;;   "Regexp for `as8051-mode' for matching numeric constants.")
;; Original above
(defconst as8051-constant-regexp
  "\\<$?[^_a-z]?\\([0][bBoOqQdDhHxX]\\)?[0-9][0-9a-f]*\\>"
  "Regexp for `as8051-mode' for matching numeric constants.")


(defconst as8051-section-name-regexp
  "^\\s-*section[ \t]+\\(\\_<\\.[a-zA-Z0-9_$#@~.?]+\\_>\\)"
  "Regexp for `as8051-mode' for matching section names.")

(defmacro as8051--opt (keywords)
  "Prepare KEYWORDS for `looking-at'."
  `(eval-when-compile
     (regexp-opt ,keywords 'words)))

(defconst as8051-imenu-generic-expression
  `((nil ,(concat "^\\s-*" as8051-nonlocal-label-rexexp) 1)
    (nil ,(concat (as8051--opt '("%define" "%macro"))
                  "\\s-+\\([a-zA-Z0-9_$#@~.?]+\\)") 2))
  "Expressions for `imenu-generic-expression'.")

(defconst as8051-full-instruction-regexp
  (eval-when-compile
    (let ((pfx (as8051--opt as8051-prefix))
          (ins (as8051--opt as8051-instructions)))
      (concat "^\\(" pfx "\\s-+\\)?" ins "$")))
  "Regexp for `as8051-mode' matching a valid full 8051 instruction field.
This includes prefixes or modifiers (eg \"mov\", \"rep mov\", etc match)")

(defconst as8051-font-lock-keywords
  `((,as8051-section-name-regexp (1 'as8051-section-name))
    (,(as8051--opt as8051-registers) . 'as8051-registers)
    (,(as8051--opt as8051-sfr-bits) . 'as8051-sfr-bits)
    (,(as8051--opt as8051-prefix) . 'as8051-prefix)
    (,(as8051--opt as8051-types) . 'as8051-types)
    (,(as8051--opt as8051-instructions) . 'as8051-instructions)
    (,(as8051--opt as8051-pp-directives) . 'as8051-preprocessor)
    (,(concat "^\\s-*" as8051-nonlocal-label-rexexp) (1 'as8051-labels))
    (,(concat "^\\s-*" as8051-local-label-regexp) (1 'as8051-local-labels))
    (,as8051-constant-regexp . 'as8051-constant)
    (,(as8051--opt as8051-directives) . 'as8051-directives))
  "Keywords for `as8051-mode'.")

(defconst as8051-mode-syntax-table
  (with-syntax-table (copy-syntax-table)
    (modify-syntax-entry ?_  "w")
    (modify-syntax-entry ?#  "_")
    (modify-syntax-entry ?@  "_")
    (modify-syntax-entry ?\? "_")
    (modify-syntax-entry ?~  "_")
    (modify-syntax-entry ?\. "w")
    (modify-syntax-entry ?\; "<")
    (modify-syntax-entry ?\n ">")
    (modify-syntax-entry ?\" "\"")
    (modify-syntax-entry ?\' "\"")
    (modify-syntax-entry ?\` "\"")
    (syntax-table))
  "Syntax table for `as8051-mode'.")

(defvar as8051-mode-map
  (let ((map (make-sparse-keymap)))
    (prog1 map
      (define-key map (kbd ":") #'as8051-colon)
      (define-key map (kbd ";") #'as8051-comment)
      (define-key map [remap join-line] #'as8051-join-line)))
  "Key bindings for `as8051-mode'.")

(defun as8051-colon ()
  "Insert a colon and convert the current line into a label."
  (interactive)
  (call-interactively #'self-insert-command)
  (as8051-indent-line))

(defun as8051-indent-line ()
  "Indent current line (or insert a tab) as ASXXXX assembly code.
This will be called by `indent-for-tab-command' when TAB is
pressed. We indent the entire line as appropriate whenever POINT
is not immediately after a mnemonic; otherwise, we insert a tab."
  (interactive)
  (let ((before      ; text before point and after indentation
         (save-excursion
           (let ((point (point))
                 (bti (progn (back-to-indentation) (point))))
             (buffer-substring-no-properties bti point)))))
    (if (string-match as8051-full-instruction-regexp before)
        ;; We are immediately after a mnemonic
        (cl-case as8051-after-mnemonic-whitespace
          (:tab   (insert "\t"))
          (:space (insert-char ?\s as8051-basic-offset)))
      ;; We're literally anywhere else, indent the whole line
      (let ((orig (- (point-max) (point))))
        (back-to-indentation)
        (if (or (looking-at (as8051--opt as8051-directives))
                (looking-at (as8051--opt as8051-pp-directives))
                (looking-at "\\[")
                (looking-at ";;+")
                (looking-at as8051-label-regexp))
            (indent-line-to 0)
          (indent-line-to as8051-basic-offset))
        (when (> (- (point-max) orig) (point))
          (setf (point) (- (point-max) orig)))))))

(defun as8051--current-line ()
  "Return the current line as a string."
  (save-excursion
    (let ((start (progn (beginning-of-line) (point)))
          (end (progn (end-of-line) (point))))
      (buffer-substring-no-properties start end))))

(defun as8051--empty-line-p ()
  "Return non-nil if current line has non-whitespace."
  (not (string-match-p "\\S-" (as8051--current-line))))

(defun as8051--line-has-comment-p ()
  "Return non-nil if current line contains a comment."
  (save-excursion
    (end-of-line)
    (nth 4 (syntax-ppss))))

(defun as8051--line-has-non-comment-p ()
  "Return non-nil of the current line has code."
  (let* ((line (as8051--current-line))
         (match (string-match-p "\\S-" line)))
    (when match
      (not (eql ?\; (aref line match))))))

(defun as8051--inside-indentation-p ()
  "Return non-nil if point is within the indentation."
  (save-excursion
    (let ((point (point))
          (start (progn (beginning-of-line) (point)))
          (end (progn (back-to-indentation) (point))))
      (and (<= start point) (<= point end)))))

(defun as8051-comment-indent ()
  "Compute desired indentation for comment on the current line."
  comment-column)

(defun as8051-insert-comment ()
  "Insert a comment if the current line doesn’t contain one."
  (let ((comment-insert-comment-function nil))
    (comment-indent)))

(defun as8051-comment (&optional arg)
  "Begin or edit a comment with context-sensitive placement.

The right-hand comment gutter is far away from the code, so this
command uses the mark ring to help move back and forth between
code and the comment gutter.

* If no comment gutter exists yet, mark the current position and
  jump to it.
* If already within the gutter, pop the top mark and return to
  the code.
* If on a line with no code, just insert a comment character.
* If within the indentation, just insert a comment character.
  This is intended prevent interference when the intention is to
  comment out the line.

With a prefix arg, kill the comment on the current line with
`comment-kill'."
  (interactive "p")
  (if (not (eql arg 1))
      (comment-kill nil)
    (cond
     ;; Empty line, or inside a string? Insert.
     ((or (as8051--empty-line-p) (nth 3 (syntax-ppss)))
      (insert ";"))
     ;; Inside the indentation? Comment out the line.
     ((as8051--inside-indentation-p)
      (insert ";"))
     ;; Currently in a right-side comment? Return.
     ((and (as8051--line-has-comment-p)
           (as8051--line-has-non-comment-p)
           (nth 4 (syntax-ppss)))
      (setf (point) (mark))
      (pop-mark))
     ;; Line has code? Mark and jump to right-side comment.
     ((as8051--line-has-non-comment-p)
      (push-mark)
      (comment-indent))
     ;; Otherwise insert.
     ((insert ";")))))

(defun as8051-join-line (join-following-p)
  "Like `join-line', but use a tab when joining with a label."
  (interactive "*P")
  (join-line join-following-p)
  (if (looking-back as8051-label-regexp (line-beginning-position))
      (let ((column (current-column)))
        (cond ((< column as8051-basic-offset)
               (delete-char 1)
               (insert-char ?\t))
              ((and (= column as8051-basic-offset) (eql ?: (char-before)))
               (delete-char 1))))
    (as8051-indent-line)))

;;;###autoload
(define-derived-mode as8051-mode prog-mode "ASXXXX 8051"
  "Major mode for editing ASXXXX 8051 assembly programs."
  :group 'as8051-mode
  (make-local-variable 'indent-line-function)
  (make-local-variable 'comment-start)
  (make-local-variable 'comment-insert-comment-function)
  (make-local-variable 'comment-indent-function)
  (setf font-lock-defaults '(as8051-font-lock-keywords nil :case-fold)
        indent-line-function #'as8051-indent-line
        comment-start ";"
        comment-indent-function #'as8051-comment-indent
        comment-insert-comment-function #'as8051-insert-comment
        imenu-generic-expression as8051-imenu-generic-expression))

(provide 'as8051-mode)

;;; as8051-mode.el ends here
