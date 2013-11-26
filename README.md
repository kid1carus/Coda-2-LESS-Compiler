Coda-2-LESS-Compiler
====================

A LESS compiler for Coda 2

[Download the plugin here!](https://github.com/mjvotaw/Coda-2-LESS-Compiler/raw/master/LESSCompile.codaplugin.zip)


What does this do?
------------------
This plugin provides LESS compilation straight into Coda--no more having to remember to open a second app just to sit there and compile your less for you.


How do you use it?
------------------

Once you install the plugin, you can add .less files to be watched by going to Plug-Ins > LESS Compiler > File Settings.
Then, hit the folder icon and select your less file. LESS Compiler will add it, and watch it AND any @imported files.

![File Settings](/stuff/Less file settings.png)

The preferences menu provides various options for how LESS Compiler notifies you.
![Preferences](/stuff/Less preferences.png)

Limitations
-----------

The biggest current limitation is that LESS Compiler cannot yet mark the saved css file for publishing. Hopefully soon, this will be a possibility. 

This compiler does not have its own log, but it DOES barf a lot of stuff into system.log. Lines from this plugin start with 'LESS::'.


Change Log
----------

0.3
---
- Setup database to live in NSHomeDirectory(), to prevent it from being overwritten on new plugin versions.
- Setup NsOpen/NSSave dialogs to default to current site directory (as best as it can determine);
- A couple little ui things, too.