;; -*- lexical-binding: t; -*-

;; 彻底关闭 native compilation
(setq native-comp-jit-compilation nil)
(setq native-comp-deferred-compilation nil)
(setq native-comp-async-report-warnings-errors nil)

;;(setq native-comp-speed 3
;;      native-comp-deferred-compilation t
;;      package-native-compile t)
;;(setq warning-minimum-level :error)
;;(setq native-comp-jit-compilation-deny-list '(".*-loaddefs.el.gz"))
;;(setq completion-auto-help nil)

;;启动优化
(setq gc-cons-threshold (* 50 1000 1000))

;; 不加载 .elc，优先用 .el
(setq load-prefer-newer t)

;; 禁止生成 .elc（byte-compile）
(setq byte-compile-warnings nil)
(setq byte-compile-verbose nil)

;;启动界面
(setq inhibit-startup-screen t)
(setq initial-buffer-choice (lambda () (progn   (dired "~/")   )))

;;(add-hook 'emacs-startup-hook (lambda ()
;;                                (when (get-buffer "*scratch*")
;;                                  (kill-buffer "*scratch*"))))


;;隐藏message
;;(setq-default message-log-max nil)
;;(kill-buffer "*Messages*")

(add-to-list 'load-path "~/.emacs.d/lisp")
(add-to-list 'custom-theme-load-path "~/.emacs.d/lisp")


;;;大文件优化
(setq-default bidi-paragraph-direction 'left-to-right)
(setq bidi-inhibit-bpa t)
(setq-default bidi-display-reordering nil)

(setq long-line-threshold 1000)
(setq large-hscroll-threshold 1000)
(setq syntax-wholeline-max 1000)

;;(global-so-long-mode 1)
;; (setq-default cursor-in-non-selected-windows nil)
;; (setq fast-but-imprecise-scrolling t)

