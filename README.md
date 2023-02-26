# .stumpwm.d

This is my stumpwm configuration. You can clone it in `~/.stumpwm.d`.

## System-Local Configuration

On occasion, I need to use slightly different parameters on my different
computers. For example, on Ubuntu the Google Chrome executable is named
`google-chrome` while on Arch Linux it's `google-chrome-stable`.

These so-called system-local parameters defined at the top of the `init.lisp`
files. They can be overridden in a file named `local.lisp`. For example, if you
want to change the terminal in use, you can put the following in your
`local.lisp` file:

``` common-lisp
(setf *terminal-cmdline* "xterm")
(setf *terminal-class* "XTerm")
```

Notice that you need to set both the command to run and the window class, so
that `run-or-raise` can work correctly.
