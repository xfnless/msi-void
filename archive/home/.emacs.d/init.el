;;; -*- lexical-binding: t -*-

;; clean
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 32 1024 1024))
            (setq gc-cons-percentage 0.1)))

(setq gc-cons-threshold 100000000) ; 100 mb
(setq read-process-output-max (* 1024 1024)) ; 1mb
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(fringe-mode -1)
(blink-cursor-mode -1)
(setq use-short-answers t)
(delete-selection-mode t)
(setq ring-bell-function 'ignore)
(setq save-silently t)

(setq read-extended-command-predicate
      #'command-completion-default-include-p)



;;; better
(prefer-coding-system 'utf-8-unix)
;;设置字体
(dolist (charset '(kana han cjk-misc bopomofo))
  (set-fontset-font t charset
                    (font-spec :family "WenQuanYi Micro Hei Mono")))

(set-face-attribute 'default nil :family "Inconsolata" :height 160)



(setq column-number-mode t
      mode-line-in-non-selected-windows t)

(setq switch-to-buffer-obey-display-actions t)

(setq-default truncate-lines t)
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))


(setq make-backup-files nil)
(setq create-lockfiles nil)
;; 自动保存
;; (setq auto-save-visited-interval 1)
;; (auto-save-visited-mode 1)
(setq auto-save-timeout 5)
(setq auto-save-interval 50)
;; 自动保存文件放到单独目录
(setq auto-save-file-name-transforms
      `((".*" "~/.emacs.d/auto-save-files/" t)))
;; 自动保存列表也放这里
(setq auto-save-list-file-prefix "~/.emacs.d/auto-save-files/.saves-")



(setq scroll-conservatively 101)   ; 光标靠近边界才滚动
(setq scroll-margin 2)             ; 顶部/底部预留2行
(setq scroll-step 1)               ; 每次滚动一行
(setq redisplay-dont-pause t)
(electric-pair-mode 1)
;; (show-paren-mode 1)
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
;; (global-display-line-numbers-mode)
(save-place-mode t)
(savehist-mode t)
(recentf-mode t)
(global-auto-revert-mode t)

;; (setq completions-format 'one-column)
;; (setq completions-max-height 15)
;; (setq completion-auto-help 'visible
;;         completion-auto-select 'second-tab
;;         completion-show-help nil
;;         completions-sort 'historical
;;         completions-header-format nil)

;; (setq icomplete-in-buffer t)
;; (setq icomplete-prospects-height 10)
;; (advice-add 'completion-at-point :after #'minibuffer-hide-completions)
;; (global-completion-preview-mode)

;;(icomplete-vertical-mode t)
;;(fido-vertical-mode 1)
;; (setq completion-styles '(initials flex substring))
;; (setq completion-category-overrides
;;       '((file (styles partial-completion))))

;;dired
(setq dired-kill-when-opening-new-dired-buffer t)
;; (add-hook 'dired-mode-hook #'dired-hide-details-mode)
(setq dired-listing-switches "-alh --no-group")
(add-hook 'dired-mode-hook 'auto-revert-mode)
(setq dired-dwim-target t) ;当两个 dired 窗口打开时，自动从一个位置复制到另一个位置
(put 'dired-find-alternate-file 'disabled nil)


(use-package dabbrev
  :custom
  (dabbrev-ignored-buffer-regexps '("\\.\\(?:pdf\\|jpe?g\\|png\\)\\'")))

(setq window-resize-pixelwise t)
(setq frame-resize-pixelwise t)
(setq load-prefer-newer t)
(setq backup-by-copying t)
(setq backup-directory-alist `(("." . ,(concat user-emacs-directory "backups"))))


(setq uniquify-buffer-name-style 'forward)


;; tramp
(setq tramp-default-method "ssh")
(setq tramp-verbose 1)
(setq vc-ignore-dir-regexp
      (format "%s\\|%s"
              vc-ignore-dir-regexp
              tramp-file-name-regexp))
(setq backup-inhibited t)
(setq tramp-use-ssh-controlmaster-options t)
(setq tramp-chunksize 2000)
(setq tramp-use-ssh-controlmaster-options t)

;; org
(setq org-ellipsis "…")
(setq org-hide-leading-stars t)
(add-hook 'org-mode-hook #'org-indent-mode)
(org-babel-do-load-languages
 'org-babel-load-languages '
 ((js . t)))
(setq org-confirm-babel-evaluate nil)
(require 'uniquify) ; 重复 buffer 区分成 index.js 和 index.js<2>

(which-key-mode 1)
(setq which-key-idle-delay 0.8)




;;; manual package
;; (require 'vv-mode)


;;




;; package init
(setq gnutls-use-ipv6 nil)
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)


;;; theme
;; (load-theme 'wombat t)


(require 'my-package)
;;(require 'my-meow)
;;(require 'owo-mode)



;;(require 'bracket-content-flash)
;;(bracket-content-flash-mode 1)
(require 'my-pyisearch)

(define-key isearch-mode-map (kbd "DEL") #'isearch-del-char)
(define-key isearch-mode-map (kbd "C-g") #'isearch-cancel)

;; 你
(require 'org-id)
(setq org-id-link-to-org-use-id 'create-if-interactive-and-no-custom-id)

;; (defun +org/opened-buffer-files ()
;;   "Return the list of files currently opened in emacs"
;;   (delq nil
;;         (mapcar (lambda (x)
;;                   (if (and (buffer-file-name x)
;;                            (string-match "\\.org$"
;;                                          (buffer-file-name x)))
;;                       (buffer-file-name x)))
;;                 (buffer-list))))
                                        ;(setq org-refile-targets '((+org/opened-buffer-files :maxlevel . 9)))
(setq org-refile-targets
      '((("~/agarden" . nil) :maxlevel . 3)))


(setq org-refile-use-outline-path 'file)
(setq org-outline-path-complete-in-steps nil)
(setq org-refile-allow-creating-parent-nodes 'confirm)

;; (defun +org-search ()
;;   (interactive)
;;   (org-refile '(4)))
;; (setq org-refile-use-cache t)
;; (run-with-idle-timer 300 t (lambda ()
;;                             (org-refile-cache-clear)
;;                             (org-refile-get-targets)))

;; (require 'org-super-links)
;; (global-set-key (kbd "C-c s s") #'org-super-links-link)
;; (global-set-key (kbd "C-c s l") #'org-super-links-store-link)
;; (global-set-key (kbd "C-c s C-l") #'org-super-links-insert-link)
;; ;; (use-package org-super-links
;;   :vc (:url "https://github.com/toshism/org-super-links")
;;   :bind (("C-c s s" . org-super-links-link)
;;          ("C-c s l" . org-super-links-store-link)
;;          ("C-c s C-l" . org-super-links-insert-link)
;;          ("C-c s d" . org-super-links-quick-insert-drawer-link)
;;          ("C-c s i" . org-super-links-quick-insert-inline-link)
;;          ("C-c s C-d" . org-super-links-delete-link)))





(setq org-attach-id-dir "~/agarden/assets")
(defun my/org-insert-asset ()
  (interactive)
  (let* ((src (read-file-name "选择文件: "))
         (assets-dir (expand-file-name "assets"
                                       (file-name-directory (buffer-file-name))))
         (dst (expand-file-name
               (file-name-nondirectory src)
               assets-dir)))
    (unless (file-directory-p assets-dir)
      (make-directory assets-dir))
    (copy-file src dst t)
    (insert (format "[[file:assets/%s]]"
                    (file-name-nondirectory src)))))
(setq org-agenda-files '("~/agarden"))
(setq org-todo-keywords '((sequence "TODO" "DONE")))
(global-set-key (kbd "C-c a") 'org-agenda)
(global-set-key "\C-cl" 'org-store-link)
(setq org-special-ctrl-a/e t)
(setq org-special-ctrl-k t)
(setq org-return-follow-link t)


;; (custom-set-faces
;;  '(cursor ((t (:background "orange")))))


;;ibuffer
(global-set-key (kbd "C-x C-b") 'ibuffer)

;; Dependencies
;; 借鉴 f,t,{[,avy g,gj gk,IA,oO,d-kill,surround-move/pair,mm,*-n/N,comment

;; (use-package dash :ensure t)
;; (use-package avy :ensure t)
;; (use-package pcre2el :ensure t)
;; (use-package hel
;;   :vc (:url "https://github.com/anuvyklack/hel.git" :rev "main")
;;   :custom (inhibit-startup-screen t)
;;   :config (hel-mode))

