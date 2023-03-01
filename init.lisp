;;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10.;  -*-

(in-package :stumpwm)

;;; parameters (can be set in local-before.lisp)

(defparameter *contrib-dir* "~/source/stumpwm-contrib/")
(defparameter *file-manager-cmdline* "nautilus --no-desktop")
(defparameter *file-manager-class* "org.gnome.Nautilus")
(defparameter *slynk-port* 4004)
(defparameter *terminal-class* "st")
(defparameter *terminal-cmdline* "st")
(defparameter *wallpaper-file* nil)
(defparameter *web-browser-class* "Google-chrome")
(defparameter *web-browser-cmdline* "google-chrome")

;;; load system-local config file, if it exists.

(defvar *local-before-config-file* "~/.stumpwm.d/local-before.lisp"
  "This file is loaded at the beginning of init.lisp, allowing for some
system-local parameters to be set before the config proper is loaded.")

(defvar *local-after-config-file* "~/.stumpwm.d/local-after.lisp"
  "This file is loaded at the end of init.lisp, allowing for some
system-local changes to be made (like changing key bindings, etc).")

(when (probe-file *local-before-config-file*)
  (load *local-before-config-file*))

;;;

;; consider only the current group in run-or-raise. this can also be
;; set per invocation, if desired.
(setf *run-or-raise-all-groups* nil)

(defun cat (&rest strings) "A shortcut for (concatenate 'string foo bar)."
  (apply 'concatenate 'string strings))

(set-module-dir *contrib-dir*)

;;;

(set-prefix-key (kbd "C-j"))

;;;

;; these commands are mainly intended to be called by external
;; commands through the use of stumpish
(defcommand stumpwm-input (prompt) ((:string "prompt: "))
  "prompts the user for one line of input."
  (read-one-line (current-screen) prompt))

(defcommand stumpwm-password (prompt) ((:string "prompt: "))
  "prompts the user for a password."
  (read-one-line (current-screen) prompt :password t))

;;;

;; slynk should be loaded using (ql:quicklisp :slynk) before building stumpwm
;; run sly-connect in emacs to connect to the server.
(require :slynk)
(when *initializing*
  (slynk:create-server :port *slynk-port*
                       :dont-close t))

;;;

(defcommand terminal () ()
  "Start terminal or switch to it, if it is already running."
  (run-or-raise *terminal-cmdline* `(:class ,*terminal-class*)))
(define-key *root-map* (kbd "C-c") "terminal")

(defcommand new-terminal () ()
  "Start terminal or switch to it, if it is already running."
  (run-shell-command *terminal-cmdline*))
(define-key *root-map* (kbd "c") "new-terminal")

;;; Web browser

(defun %web-browser (&optional (url ""))
  (run-or-raise
   (format nil "~a ~a" *web-browser-cmdline* url)
   `(:class ,*web-browser-class*)))

(defcommand web-browser () ()
  "Start web browser or switch to it, if it is already running."
  (%web-browser))
(define-key *root-map* (kbd "x") (format nil "exec ~a" *web-browser-cmdline*))
(define-key *root-map* (kbd "C-x") "web-browser")

;; ask the user for a search string and search for it in Wikipedia
(defcommand wikipedia (search)
  ((:string "Search in Wikipedia for: "))
  "prompt the user for a search term and look it up in the English Wikipedia"
  (check-type search string)
  (let ((uri (format nil "http://en.wikipedia.org/wiki/Special:Search?search=~a" search)))
    (run-shell-command (format nil "~a ~a" *web-browser-cmdline* uri))))

;; ask the user for a search string and search for it in Google
(defcommand google (search)
  ((:string "Search in Google for: "))
  "prompt the user for a search term and look it up in Google "
  (check-type search string)
  (let ((uri (format nil "http://www.google.com/search?q=~a" search)))
    (run-shell-command (format nil "~a ~a" *web-browser-cmdline* uri))))

;;;

(defcommand emacs-in-tmux () ()
  "attempts to switch to an emacs instance run in a tmux window
   called 'emacs', itself inside a st instance."

  (let ((ret
         (run-shell-command "tmux select-window -t emacs ; echo $?" t)))

    (if (eql (elt ret 0) #\0)
        (run-or-raise *terminal-cmdline* `(:class ,*terminal-class*))
        (message "no tmux session found."))))
(define-key *root-map* (kbd "C-e") "emacs-in-tmux")

;;;

;; setup volume control key bindings
(defcommand volume-up () ()
  "Increases master volume by 5 percent."
  (let ((result (run-shell-command "amixer -D pulse sset Master 5%+" t)))
    (cl-ppcre:register-groups-bind (pct) ("\\[(\\d+)%\\]" result)
      (message "~a%" pct))))
(define-key *top-map* (kbd "XF86AudioRaiseVolume") "volume-up")

(defcommand volume-down () ()
  "Increases master volume by 5 percent."
  (let ((result (run-shell-command "amixer -D pulse sset Master 5%-" t)))
    (cl-ppcre:register-groups-bind (pct) ("\\[(\\d+)%\\]" result)
      (message "~a%" pct))))
(define-key *top-map* (kbd "XF86AudioLowerVolume") "volume-down")

(defcommand volume-mute-toggle () ()
  "Mutes/Unmutes the master volume."
  (cl-ppcre:register-groups-bind (state)
      ("\\[(on|off)\\]" (run-shell-command "amixer -D pulse" t))
    (run-shell-command (if (equalp state "on")
                           "amixer -D pulse sset Master mute"
                           "amixer -D pulse sset Master unmute"))
    (message (if (equalp state "on") "muted." "unmuted."))))
(define-key *top-map* (kbd "XF86AudioMute") "volume-mute-toggle")

;;;

;; setup playback key bindings

(defun get-first-capture (regex string)
  (cl-ppcre:register-groups-bind (group)
      ((cl-ppcre:create-scanner regex :multi-line-mode t) string)
    group))

(defcommand music-status () ()
  (let* ((out (run-shell-command "playerctl metadata" t))
         (artist (get-first-capture "^\.+ xesam:artist +(.*)$" out))
         (album (get-first-capture "^\.+ xesam:album +(.*)$" out))
         (title (get-first-capture "^\.+ xesam:title\\s+(.*)$" out))
         (status (run-shell-command "playerctl status" t)))
    (message (format nil "~a~%~a~%~a - ~a" status title artist album))))

(defcommand music-prev () ()
  "Go to the previous music track."
  (run-shell-command "playerctl previous")
  (music-status))

(defcommand music-next () ()
  "Go to the next music track."
  (run-shell-command "playerctl next")
  (music-status))

(defcommand music-toggle-play-pause () ()
  "Play/pause music playback."
  (run-shell-command "playerctl play-pause")
  (music-status))

(defcommand music-stop () ()
  "Stop music playback."
  (run-shell-command "playerctl stop")
  (message "stop"))

(define-key *top-map* (kbd "XF86AudioPrev") "music-prev")
(define-key *top-map* (kbd "XF86AudioNext") "music-next")
(define-key *top-map* (kbd "XF86AudioPlay") "music-toggle-play-pause")
(define-key *top-map* (kbd "XF86AudioStop") "music-stop")

;; Screenshot capture. Needs zpng package installed: `(ql:quickload :zpng)`

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require 'asdf)
  (asdf:load-system 'zpng))

(defcommand screenshot
    (filename)
    ((:rest "Filename: "))
  "Make screenshot of root window"
  (%screenshot-window (screen-root (current-screen)) filename))

(defcommand screenshot-window
    (filename)
    ((:rest "Filename: "))
  "Make screenshot of focus window"
  (%screenshot-window (window-xwin (current-window)) filename))

(defun %screenshot-window (drawable file &key (height (xlib:drawable-height drawable))
                                        (width (xlib:drawable-width drawable)))
  (let* ((png (make-instance 'zpng:pixel-streamed-png
                            :color-type :truecolor-alpha
                            :width width
                            :height height)))
    (multiple-value-bind (pixarray depth visual)
        (xlib:get-raw-image drawable :x 0 :y 0 :width width :height height
                :format :Z-PIXMAP)
      (with-open-file (stream file
                              :direction :output
                              :if-exists :supersede
                              :if-does-not-exist :create
                              :element-type '(unsigned-byte 8))
        (zpng:start-png png stream)
        ;;(zpng:write-row pixarray png)
        (case (xlib:display-byte-order (xlib:drawable-display drawable))
          (:lsbfirst
           (do ((i 0 (+ 4 i)))
               ((>= i (length pixarray)))
             (zpng:write-pixel (list (aref pixarray (+ 2 i))
                                     (aref pixarray (+ 1 i))
                                     (aref pixarray i)
                                     #xFF)
                               png)))
          (:msbfirst
           (do ((i 0 (+ 4 i)))
               ((>= i (* height width 4)))
             (zpng:write-pixel (list (aref pixarray (1+ i))
                                     (aref pixarray (+ 2 i))
                                     (aref pixarray (+ 3 i))
                                     #xFF)
                               png)
             )))
        (zpng:finish-png png)))))

(define-key *top-map* (kbd "Print") "screenshot")
(define-key *top-map* (kbd "Sys_Req") "screenshot-window") ; Shift+Print Screen

;;; screen locking

(defcommand lock-screen () ()
  "Lock the screen"
  (run-shell-command "slock"))

(define-key *root-map* (kbd "L") "lock-screen")

;;; file manager

(defcommand file-manager () ()
  (run-or-raise *file-manager-cmdline* `(:class ,*file-manager-class*)))

(define-key *root-map* (kbd "N") "file-manager")

;;; backlight (screen brightness)

(load-module "stump-backlight")

(define-key *top-map* (kbd "XF86MonBrightnessUp") "backlight-increase")
(define-key *top-map* (kbd "XF86MonBrightnessDown") "backlight-decrease")

;;; initialize groups

(when *initializing*
  (grename "Youtube")  ; rename default group
  (gnewbg "Steam")
  (gnewbg "Work")
  (gnewbg "Web")
  (gnewbg "VM"))

;; control the rat using keyboard

(load-module "binwarp")
(binwarp:define-binwarp-mode my-binwarp-mode "s-m" (:map *top-map*)
  ((kbd "SPC") "ratclick 1")
  ((kbd "RET") "ratclick 3")
  ((kbd "C-b") "binwarp left")
  ((kbd "C-n") "binwarp down")
  ((kbd "C-p") "binwarp up")
  ((kbd "C-f") "binwarp right")
  ((kbd "i")   "init-binwarp"))

;;;

;; - switch keyboard layouts between English and Persian by pressing both shift
;;   keys.
;; - swap ctrl and alt keys
(run-shell-command
 "setxkbmap \"pc+us+ir:2+inet(evdev)+group(shifts_toggle)\" -option ctrl:swap_lalt_lctl -option ctrl:swap_ralt_rctl"
 t)

;; make the mouse pointer an arrow
(run-shell-command "xsetroot -cursor_name left_ptr")

;; set desktop wallpaper
(when (and *initializing* *wallpaper-file*)
  (run-shell-command (format nil "feh --bg-scale ~a" *wallpaper-file*)))

;;;

(when (probe-file *local-after-config-file*)
  (load *local-after-config-file*))
