# Just Inline It

Do you like inlining? Do you hate seeing those silly constructors everywhere? **Just Inline It!**


Tired of `.mutableAdd` and `.add` in your vector libraries? **Just Inline It!**


Does `new` cause you anguish? **Just Inline It!**


Do you want (near) zero overhead `map`/`filter`/`fold`/`_`? **JUST INLINE IT!!**  
(*control over inline during macro phase allows for rewrite rules*)


## Why?

* https://github.com/HaxeFoundation/haxe/issues/5495
* https://github.com/HaxeFoundation/haxe/issues/5462
* Adds control over inline during macro execution


## What?

Utilizes typedExpr to force inlining via macros.

Additonally does eta contraction, and simplifies expressions to allow more constructor inlining to occur.

## Should I use this?

Probably not (yet)
