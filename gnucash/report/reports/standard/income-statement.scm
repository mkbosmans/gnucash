;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; income-statement.scm: income statement (a.k.a. Profit & Loss)
;; 
;; By David Montenegro <sunrise2000@comcast.net>
;;  2004.07.13 - 2004.07.14
;;
;;  * BUGS:
;;    
;;    This code makes the assumption that you want your income
;;    statement to no more than daily resolution.
;;    
;;    Line & column alignments may still not conform with
;;    textbook accounting practice (they're close though!).
;;    
;;    Progress bar functionality is currently mostly broken.
;;    
;;    The variables in this code could use more consistent naming.
;;    
;;    See also all the "FIXME"s in the code.
;;    
;; This program is free software; you can redistribute it and/or    
;; modify it under the terms of the GNU General Public License as   
;; published by the Free Software Foundation; either version 2 of   
;; the License, or (at your option) any later version.              
;;                                                                  
;; This program is distributed in the hope that it will be useful,  
;; but WITHOUT ANY WARRANTY; without even the implied warranty of   
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the    
;; GNU General Public License for more details.                     
;;                                                                  
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, contact:
;;
;; Free Software Foundation           Voice:  +1-617-542-5942
;; 51 Franklin Street, Fifth Floor    Fax:    +1-617-542-2652
;; Boston, MA  02110-1301,  USA       gnu@gnu.org
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-module (gnucash reports standard income-statement))
(use-modules (gnucash engine))
(use-modules (gnucash utilities))
(use-modules (gnucash core-utils))
(use-modules (gnucash app-utils))
(use-modules (gnucash report))

;; define all option's names and help text so that they are properly
;; defined in *one* place.
(define optname-report-title (N_ "Report Title"))
(define opthelp-report-title (N_ "Title for this report."))

(define optname-start-date (N_ "Start Date"))
(define optname-end-date (N_ "End Date"))

(define optname-accounts (N_ "Accounts"))
(define opthelp-accounts
  (N_ "Report on these accounts, if display depth allows."))
(define optname-depth-limit (N_ "Levels of Subaccounts"))
(define opthelp-depth-limit
  (N_ "Maximum number of levels in the account tree displayed."))
(define optname-bottom-behavior (N_ "Flatten list to depth limit"))
(define opthelp-bottom-behavior
  (N_ "Displays accounts which exceed the depth limit at the depth limit."))

(define optname-parent-balance-mode (N_ "Parent account balances"))
(define optname-parent-total-mode (N_ "Parent account subtotals"))

(define optname-show-zb-accts (N_ "Include accounts with zero total balances"))
(define opthelp-show-zb-accts
  (N_ "Include accounts with zero total (recursive) balances in this report."))
(define optname-omit-zb-bals (N_ "Omit zero balance figures"))
(define opthelp-omit-zb-bals
  (N_ "Show blank space in place of any zero balances which would be shown."))

(define optname-use-rules (N_ "Show accounting-style rules"))
(define opthelp-use-rules
  (N_ "Use rules beneath columns of added numbers like accountants do."))

(define optname-account-links (N_ "Display accounts as hyperlinks"))
(define opthelp-account-links (N_ "Shows each account in the table as a hyperlink to its register window."))

(define optname-label-revenue (N_ "Label the revenue section"))
(define opthelp-label-revenue
  (N_ "Whether or not to include a label for the revenue section."))
(define optname-total-revenue (N_ "Include revenue total"))
(define opthelp-total-revenue
  (N_ "Whether or not to include a line indicating total revenue."))
(define optname-label-trading (N_ "Label the trading accounts section"))
(define opthelp-label-trading
  (N_ "Whether or not to include a label for the trading accounts section."))
(define optname-total-trading (N_ "Include trading accounts total"))
(define opthelp-total-trading
  (N_ "Whether or not to include a line indicating total trading accounts balance."))
(define optname-label-expense (N_ "Label the expense section"))
(define opthelp-label-expense
  (N_ "Whether or not to include a label for the expense section."))
(define optname-total-expense (N_ "Include expense total"))
(define opthelp-total-expense
  (N_ "Whether or not to include a line indicating total expense."))

(define pagename-commodities (N_ "Commodities"))
(define optname-report-commodity (N_ "Report's currency"))
(define optname-price-source (N_ "Price Source"))
(define optname-show-foreign (N_ "Show Foreign Currencies"))
(define opthelp-show-foreign
  (N_ "Display any foreign currency amount in an account."))
(define optname-show-rates (N_ "Show Exchange Rates"))
(define opthelp-show-rates (N_ "Show the exchange rates used."))

(define pagename-entries (N_ "Entries"))
(define optname-closing-pattern (N_ "Closing Entries pattern"))
(define opthelp-closing-pattern
  (N_ "Any text in the Description column which identifies closing entries."))
(define optname-closing-casing
  (N_ "Closing Entries pattern is case-sensitive"))
(define opthelp-closing-casing
  (N_ "Causes the Closing Entries Pattern match to be case-sensitive."))
(define optname-closing-regexp
  (N_ "Closing Entries Pattern is regular expression"))
(define opthelp-closing-regexp
  (N_ "Causes the Closing Entries Pattern to be treated as a regular expression."))
(define optname-two-column
  (N_ "Display as a two column report"))
(define opthelp-two-column
  (N_ "Divides the report into an income column and an expense column."))
(define optname-standard-order
  (N_ "Display in standard, income first, order"))
(define opthelp-standard-order
  (N_ "Causes the report to display in the standard order, placing income before expenses."))

;; options generator
(define (income-statement-options-generator-internal reportname)
  (let* ((options (gnc-new-optiondb)))

    (gnc-register-string-option options
      gnc:pagename-general optname-report-title
      "a" opthelp-report-title (G_ reportname))
    
    ;; period over which to report income
    (gnc:options-add-date-interval!
     options gnc:pagename-general 
     optname-start-date optname-end-date "c")
    
    ;; accounts to work on
    (gnc-register-account-list-option options
      gnc:pagename-accounts optname-accounts
      "a"
      opthelp-accounts
	(gnc:filter-accountlist-type
	 ;; select, by default, only income and expense accounts
	 (list ACCT-TYPE-INCOME ACCT-TYPE-EXPENSE)
	 (gnc-account-get-descendants-sorted (gnc-get-current-root-account))))

    (gnc:options-add-account-levels!
     options gnc:pagename-accounts optname-depth-limit
     "b" opthelp-depth-limit 3)
    (gnc-register-simple-boolean-option options
      gnc:pagename-accounts optname-bottom-behavior
      "c" opthelp-bottom-behavior #f)
    
    ;; all about currencies
    (gnc:options-add-currency!
     options pagename-commodities
     optname-report-commodity "a")
    
    (gnc:options-add-price-source! 
     options pagename-commodities
     optname-price-source "b" 'pricedb-nearest)

    (gnc-register-simple-boolean-option options
      pagename-commodities optname-show-foreign 
      "c" opthelp-show-foreign #t)
    
    (gnc-register-simple-boolean-option options
      pagename-commodities optname-show-rates
      "d" opthelp-show-rates #f)

    ;; what to show for zero-balance accounts
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-show-zb-accts
      "a" opthelp-show-zb-accts #t)
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-omit-zb-bals
      "b" opthelp-omit-zb-bals #f)
    ;; what to show for non-leaf accounts
    (gnc:options-add-subtotal-view!
     options gnc:pagename-display
     optname-parent-balance-mode optname-parent-total-mode
     "c")

    ;; some detailed formatting options
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-account-links
      "e" opthelp-account-links #t)
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-use-rules
      "f" opthelp-use-rules #f)
    
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-label-revenue
      "g" opthelp-label-revenue #t)
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-total-revenue
      "h" opthelp-total-revenue #t)
    
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-label-trading
      "h1" opthelp-label-trading #t)
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-total-trading
      "h2" opthelp-total-trading #t)
    
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-label-expense
      "i" opthelp-label-expense #t)
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-total-expense
      "j" opthelp-total-expense #t)

    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-two-column
      "k" opthelp-two-column #f)

    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-standard-order
      "l" opthelp-standard-order #t)
    
    ;; closing entry match criteria
    ;; 
    ;; N.B.: transactions really should have a field where we can put
    ;; transaction types like "Adjusting/Closing/Correcting Entries"
    (gnc-register-string-option options
      pagename-entries optname-closing-pattern
      "a" opthelp-closing-pattern (G_ "Closing Entries"))
    (gnc-register-simple-boolean-option options
      pagename-entries optname-closing-casing
      "b" opthelp-closing-casing #f)
    (gnc-register-simple-boolean-option options
      pagename-entries optname-closing-regexp
      "c" opthelp-closing-regexp #f)
    
    ;; Set the accounts page as default option tab
    (gnc:options-set-default-section options gnc:pagename-accounts)
    
    options))

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; income-statement-renderer
;; set up the document and add the table
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (income-statement-renderer-internal report-obj reportname)
  (define (get-option pagename optname)
    (gnc-optiondb-lookup-value
      (gnc:report-options report-obj) pagename optname))

  (gnc:report-starting reportname)
  
  ;; get all option's values
  (let* (
	 (report-title (get-option gnc:pagename-general optname-report-title))
	 (company-name (or (gnc:company-info (gnc-get-current-book) gnc:*company-name*) ""))
         (start-date-printable (gnc:date-option-absolute-time
				(get-option gnc:pagename-general
					    optname-start-date)))
         (start-date (gnc:time64-start-day-time
			 (gnc:date-option-absolute-time
			  (get-option gnc:pagename-general
				      optname-start-date))))
         (end-date (gnc:time64-end-day-time
		       (gnc:date-option-absolute-time
			(get-option gnc:pagename-general
				    optname-end-date))))
         (accounts (get-option gnc:pagename-accounts
                               optname-accounts))	 
	 (depth-limit (get-option gnc:pagename-accounts 
				  optname-depth-limit))
	 (bottom-behavior (get-option gnc:pagename-accounts 
				  optname-bottom-behavior))
         (report-commodity (get-option pagename-commodities
                                      optname-report-commodity))
         (price-source (get-option pagename-commodities
                                   optname-price-source))
         (show-fcur? (get-option pagename-commodities
                                 optname-show-foreign))
         (show-rates? (get-option pagename-commodities
                                  optname-show-rates))
         (parent-balance-mode (get-option gnc:pagename-display
                                           optname-parent-balance-mode))
         (parent-total-mode
	  (assq-ref '((t . #t) (f . #f))
		    (get-option gnc:pagename-display
				optname-parent-total-mode)))
         (show-zb-accts? (get-option gnc:pagename-display
				     optname-show-zb-accts))
         (omit-zb-bals? (get-option gnc:pagename-display
				    optname-omit-zb-bals))
         (label-revenue? (get-option gnc:pagename-display
				    optname-label-revenue))
         (total-revenue? (get-option gnc:pagename-display
				    optname-total-revenue))
         (label-trading? (get-option gnc:pagename-display
				    optname-label-trading))
         (total-trading? (get-option gnc:pagename-display
				    optname-total-trading))
         (label-expense? (get-option gnc:pagename-display
				    optname-label-expense))
         (total-expense? (get-option gnc:pagename-display
				    optname-total-expense))
         (use-links? (get-option gnc:pagename-display
				     optname-account-links))
         (use-rules? (get-option gnc:pagename-display
				    optname-use-rules))
	 (closing-str (get-option pagename-entries
				  optname-closing-pattern))
	 (closing-cased (get-option pagename-entries
				    optname-closing-casing))
	 (closing-regexp (get-option pagename-entries
				     optname-closing-regexp))
	 (two-column? (get-option gnc:pagename-display
				  optname-two-column))
	 (standard-order? (get-option gnc:pagename-display
				      optname-standard-order))
	 (closing-pattern
	  (list (list 'str closing-str)
		(list 'cased closing-cased)
		(list 'regexp closing-regexp)
		(list 'closing #t)))

         ;; decompose the account list
         (split-up-accounts (gnc:decompose-accountlist accounts))
	 (revenue-accounts (assoc-ref split-up-accounts ACCT-TYPE-INCOME))
	 (trading-accounts (assoc-ref split-up-accounts ACCT-TYPE-TRADING))
	 (expense-accounts (assoc-ref split-up-accounts ACCT-TYPE-EXPENSE))
	 
         (doc (gnc:make-html-document))
	 ;; this can occasionally put extra (blank) columns in our
	 ;; table (when there is one account at the maximum depth and
	 ;; it has at least one of its ancestors deselected), but this
	 ;; is the only simple way to ensure that both tables
	 ;; (revenue, expense) have the same width.
         (tree-depth (if (equal? depth-limit 'all)
                         (gnc:get-current-account-tree-depth) 
			 depth-limit))
         ;; exchange rates calculation parameters
	 (exchange-fn
	  (gnc:case-exchange-fn price-source report-commodity end-date))
         (price-fn (gnc:case-price-fn price-source report-commodity end-date)))

    ;; Wrapper to call gnc:html-table-add-labeled-amount-line!
    ;; with the proper arguments.
    (define (add-subtotal-line table pos-label neg-label signed-balance)
      (let* ((neg? (and signed-balance neg-label
                        (negative?
                         (gnc:gnc-monetary-amount
                          (gnc:sum-collector-commodity
                           signed-balance report-commodity exchange-fn)))))
             (label (if neg? (or neg-label pos-label) pos-label))
             (balance (if neg? (gnc:collector- signed-balance) signed-balance)))
        (gnc:html-table-add-labeled-amount-line!
         table (* tree-depth 2) "primary-subheading" #f label 0 1 "total-label-cell"
         (gnc:sum-collector-commodity balance report-commodity exchange-fn)
         (1- (* tree-depth 2)) 1 "total-number-cell")))

    ;; wrapper around gnc:html-table-append-ruler!
    (define (add-rule table)
      (gnc:html-table-append-ruler! table (* 2 tree-depth)))

    (gnc:html-document-set-title!
     doc (gnc:format (G_ "${company-name} ${report-title} For Period Covering ${start} to ${end}")
                     'company-name company-name
                     'report-title report-title
                     'start (qof-print-date start-date-printable)
                     'end (qof-print-date end-date)))

    (if (null? accounts)

        ;; error condition: no accounts specified is this *really*
        ;; necessary??  i'd be fine with an all-zero P&L that would,
        ;; technically, be correct....
        (gnc:html-document-add-object!
         doc (gnc:html-make-no-account-warning
              reportname (gnc:report-id report-obj)))

        ;; Get all the balances for each of the account types.
        (let* ((expense-total
                (gnc:collector-
                 (gnc:accountlist-get-comm-balance-interval-with-closing
                  expense-accounts start-date end-date)
                 (gnc:account-get-trans-type-balance-interval-with-closing
                  expense-accounts closing-pattern start-date end-date)))

               (revenue-total
                (gnc:collector-
                 (gnc:account-get-trans-type-balance-interval-with-closing
                  revenue-accounts closing-pattern start-date end-date)
                 (gnc:accountlist-get-comm-balance-interval-with-closing
                  revenue-accounts start-date end-date)))

               (trading-total
                (gnc:accountlist-get-comm-balance-interval-with-closing
                 trading-accounts start-date end-date))

               (net-income
                (gnc:collector+ revenue-total
                                trading-total
                                (gnc:collector- expense-total)))

               (build-table (gnc:make-html-table))
               (table-env
                (list
                 (list 'start-date start-date)
                 (list 'end-date end-date)
                 (list 'display-tree-depth tree-depth)
                 (list 'depth-limit-behavior (if bottom-behavior 'flatten 'summarize))
                 (list 'report-commodity report-commodity)
                 (list 'exchange-fn exchange-fn)
                 (list 'parent-account-subtotal-mode parent-total-mode)
                 (list 'zero-balance-mode
                       (if show-zb-accts? 'show-leaf-acct 'omit-leaf-acct))
                 (list 'account-label-mode (if use-links? 'anchor 'name))
                 ;; we may, at some point, want to add an option to
                 ;; generate a pre-adjustment income statement...
                 (list 'balance-mode 'pre-closing)
                 (list 'closing-pattern closing-pattern)))

               (params
                (list
                 (list 'parent-account-balance-mode parent-balance-mode)
                 (list 'zero-balance-display-mode
                       (if omit-zb-bals? 'omit-balance 'show-balance))
                 (list 'multicommodity-mode (and show-fcur? 'table))
                 (list 'rule-mode use-rules?)))

               (revenue-table
                (gnc:make-html-acct-table/env/accts table-env revenue-accounts))
               (expense-table
                (gnc:make-html-acct-table/env/accts table-env expense-accounts))
               (trading-table
                (gnc:make-html-acct-table/env/accts table-env trading-accounts))

               (period-for (string-append " " (G_ "for Period"))))

          ;; a helper to add a line to our report
          (define (add-report-line
                   table pos-label neg-label amount col
                   exchange-fn rule? row-style)
            (let* ((mon (gnc:sum-collector-commodity
                         amount report-commodity exchange-fn))
                   (neg? (and amount neg-label
                              (negative? (gnc:gnc-monetary-amount mon))))
                   (label (if neg? (or neg-label pos-label) pos-label))
                   (bal (if neg? (gnc:monetary-neg mon) mon)))
              (gnc:html-table-add-labeled-amount-line!
               table (* 2 tree-depth)  row-style rule?
               label                0  1 "text-cell"
               bal          (+ col 1)  1 "number-cell")))

          (define (add-revenue-table table)
            (when label-revenue?
              (add-subtotal-line table (G_ "Revenues") #f #f))
            (gnc:html-table-add-account-balances table revenue-table params)
            (when total-revenue?
              (add-subtotal-line table (G_ "Total Revenue") #f revenue-total))
            table)

          (define (add-expense-table table)
            (when label-expense?
              (add-subtotal-line table (G_ "Expenses") #f #f))
            (gnc:html-table-add-account-balances table expense-table params)
            (when total-expense?
              (add-subtotal-line table (G_ "Total Expenses") #f expense-total))
            table)

          (define (add-trading-table table)
            (when label-trading?
              (add-subtotal-line table (G_ "Trading") #f #f))
            (gnc:html-table-add-account-balances table trading-table params)
            (when total-trading?
              (add-subtotal-line table (G_ "Total Trading") #f trading-total))
            table)

          (cond
           (two-column?
            (let* ((exp-table (add-expense-table (gnc:make-html-table)))
                   (inc-table (add-revenue-table (gnc:make-html-table)))
                   (tra-table (add-trading-table (gnc:make-html-table)))
                   (inc-cell (gnc:make-html-table-cell inc-table))
                   (tra-cell (if (null? trading-accounts)
                                 (gnc:html-make-empty-cell)
                                 (gnc:make-html-table-cell tra-table)))
                   (exp-cell (gnc:make-html-table-cell exp-table)))
              (define (add-cells . lst) (gnc:html-table-append-row! build-table lst))
              (add-rule (if standard-order? exp-table inc-table))
              (add-report-line
               (if standard-order? exp-table inc-table)
               (string-append (G_ "Net income") period-for)
               (string-append (G_ "Net loss") period-for)
               net-income (* 2 (1- tree-depth)) exchange-fn #f #f)
              (if standard-order?
                  (add-cells inc-cell tra-cell exp-cell)
                  (add-cells exp-cell inc-cell tra-cell))))

           ;; single-column
           (standard-order?
            (add-revenue-table build-table)
            (add-rule build-table)
            (unless (null? trading-accounts)
              (add-trading-table build-table)
              (add-rule build-table))
            (add-expense-table build-table)
            (add-rule build-table)
            (add-report-line
             build-table
             (string-append (G_ "Net income") period-for)
             (string-append (G_ "Net loss") period-for)
             net-income (* 2 (1- tree-depth)) exchange-fn #f #f))

           (else
            (add-expense-table build-table)
            (add-rule build-table)
            (unless (null? trading-accounts)
              (add-trading-table build-table)
              (add-rule build-table))
            (add-revenue-table build-table)
            (add-rule build-table)
            (add-report-line
             build-table
             (string-append (G_ "Net income") period-for)
             (string-append (G_ "Net loss") period-for)
             net-income (* 2 (1- tree-depth)) exchange-fn #f #f)))

          (gnc:html-table-set-style!
           build-table "td"
           'attribute '("align" "left")
           'attribute '("valign" "top"))

          (gnc:html-document-add-object! doc build-table)

          ;; add currency information if requested
          (gnc:report-percent-done 90)
          (when show-rates?
            (gnc:html-document-add-object!
             doc (gnc:html-make-rates-table
                  report-commodity price-fn accounts)))
          (gnc:report-percent-done 100)))

    (gnc:report-finished)

    doc))

(define is-reportname (N_ "Income Statement"))
(define pnl-reportname (N_ "Profit & Loss"))

(define (income-statement-options-generator)
  (income-statement-options-generator-internal is-reportname))
(define (income-statement-renderer report-obj)
  (income-statement-renderer-internal report-obj is-reportname))

(define (profit-and-loss-options-generator)
  (income-statement-options-generator-internal pnl-reportname))
(define (profit-and-loss-renderer report-obj)
  (income-statement-renderer-internal report-obj pnl-reportname))


(gnc:define-report 
 'version 1
 'name is-reportname
 'report-guid "0b81a3bdfd504aff849ec2e8630524bc"
 'menu-path (list gnc:menuname-income-expense)
 'options-generator income-statement-options-generator
 'renderer income-statement-renderer)

;; Also make a "Profit & Loss" report, even if it's the exact same one,
;; just relabeled.
(gnc:define-report 
 'version 1
 'name pnl-reportname
 'report-guid "8758ba23984c40dea5527f5f0ca2779e"
 'menu-path (list gnc:menuname-income-expense)
 'options-generator profit-and-loss-options-generator
 'renderer profit-and-loss-renderer)

;; END
