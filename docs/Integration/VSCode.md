---
sidebar_position: 1
---

# VS Code
To begin working with Midas you need to install the relevant [wally](https://wally.run/) package at `nightcycle/midas', adding the versioning of the most recent release at the end. As a wally package it can be retrieved from throughout the game's code.

All of the code composing the package is luau strict typechecking compliant, and if you index it directly using [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) it will be detected by the VS Code intellisense, saving you time memorizing a new API. The package also exports multiple custom luau types that may be useful in your own code, you may access them using [wally-package-types](https://github.com/JohnnyMorganz/wally-package-types) created by the same talented individual. This is my own workflow, however it is not necessary to use Midas, just recommended.

Once you are done installing and integrating the package into your VS Code workspace, the next step is integrating it into your Roblox code.