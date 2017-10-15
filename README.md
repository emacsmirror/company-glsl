[![Build Status](https://travis-ci.org/guidoschmidt/company-glsl.svg?branch=master)](https://travis-ci.org/guidoschmidt/company-glsl)
[![MELPA](https://melpa.org/packages/company-glsl-badge.svg)](https://melpa.org/#/company-glsl)

# Company GLSL

**FORKED FROM:** [Kaali/company-glsl](https://github.com/Kaali/company-glsl)

Provides GLSL Completion by using [glslangValidator](https://github.com/KhronosGroup/glslang) &
filtering types, modifiers as well as builtins.

### Usage:
```elisp
(use-package company-glsl
  :config
  (when (executable-find "glslangValidator")
    (add-to-list 'company-backends 'company-glsl)))
```
