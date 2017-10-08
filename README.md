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
