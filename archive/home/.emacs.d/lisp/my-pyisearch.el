(require 'pinyinlib)

(defun my/pinyin-search-engine ()
  "强行接管 isearch，输入 'zw' 自动匹配 'zw' 和 '中文'"
  (lambda (string &optional bound noerror count)
    (let ((pinyin-regex (pinyinlib-build-regexp-string string)))
      ;; 核心：强行调用 re-search-forward (正则搜索)，不再用普通的 search-forward
      (funcall (if isearch-forward #'re-search-forward #'re-search-backward)
               pinyin-regex bound noerror count))))

;; 覆盖默认搜索函数
(setq isearch-search-fun-function 'my/pinyin-search-engine)



;; (defun my-smart-pinyin-isearch ()
;;   "智能判断：只在输入纯小写字母时启用拼音匹配，否则保持原生搜索。"
;;   (let ((input isearch-string))
;;     (if (and input (string-match-p "^[a-z]+$" input)) 
;;         ;; 1. 如果输入全是小写字母 (如 "zw") -> 启用拼音正则模式
;;         (lambda (string &optional bound noerror count)
;;           (let ((pinyin-regex (pinyinlib-build-regexp-string string)))
;;             (funcall (if isearch-forward #'re-search-forward #'re-search-backward)
;;                      pinyin-regex bound noerror count)))
      
;;       ;; 2. 如果输入包含大写、数字、符号 (如 "Test", "123", "a.b") -> 使用原生搜索
;;       ;; 这样绝对不会影响原来的精确搜索和特殊功能
;;       (isearch-search-fun-default))))

;; (setq isearch-search-fun-function 'my-smart-pinyin-isearch)

(provide 'my-pyisearch)
