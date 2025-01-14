;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(uiop:define-package :nyxt/watch-mode
    (:use :common-lisp :nyxt)
  (:documentation "Mode for reloading buffers at regular time
  intervals."))
(in-package :nyxt/watch-mode)

(defun seconds-from-user-input ()
  "Query the numerical time inputs and collate them into seconds."
  (let* ((time-units '("days" "hours" "minutes" "seconds"))
         (to-seconds-alist (pairlis time-units '(86400 3600 60 1)))
         (active-time-units (prompt
                             :prompt "Time unit(s)"
                             :sources (make-instance 'prompter:source
                                                     :name "Units"
                                                     :constructor time-units
                                                     :multi-selection-p t)))
         (times (mapcar (lambda (unit)
                          (parse-integer
                           (first (prompt
                                   :prompt (format nil "Time interval (~a)" unit)
                                   :sources (make-instance 'prompter:raw-source)))
                           :junk-allowed t))
                        active-time-units))
         (to-seconds-multipliers
           (mapcar
            (lambda (elem) (cdr (assoc elem to-seconds-alist :test 'string-equal)))
            active-time-units)))
    (echo "Refreshing every ~:@{~{~d ~}~a~:@}"
          (list times active-time-units))
    (apply '+ (mapcar (lambda (time multiplier) (* time multiplier))
                      times to-seconds-multipliers))))

(define-mode watch-mode ()
  "Reload the current buffer at regular time intervals."
  ((thread :documentation "The thread responsible for reloading the view.")
   (sleep-time :documentation "The amount of time to sleep between reloads.")
   (destructor (lambda (mode)
                 (when (thread mode)
                   (bt:destroy-thread (thread mode)))))
   (constructor (lambda (mode)
                  (setf (sleep-time mode) (seconds-from-user-input))
                  (setf (thread mode)
                        (run-thread
                          (loop while (buffer mode)
                                do (nyxt::reload-buffers (list (buffer mode)))
                                   (sleep (sleep-time mode)))))))))
