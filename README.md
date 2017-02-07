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

Consider the following:

```haxe
class Point { 
    public var x:Float;
    public var y:Float;
    public inline function new(x = 1.0, y = 1.0) { this.x = x; this.y = y; }
    public inline function add(b:Point) return new Point(x + b.x, y + b.y);
    public inline function toString() return '($x,$y)';
}
```

Haxe:
```haxe
new Point(1,4).add(new Point(4,9));

--compiles-to--
var this1 = new PointInternal(1,4);
var this2 = new PointInternal(4,9);
var $as = this1;
var bs = this2;
var this3 = new PointInternal($as.x + bs.x,$as.y + bs.y);
var this4 = this3;
"(" + this4.x + "," + this4.y + ")";
```

Haxe + Just Inline It!:
```haxe
justInlineIt.JustInlineIt.doIt(new Point(1,4).add(new Point(4,9)));

--compiles-to--
var tmp0 = 1;
var tmp1 = 4;
var tmp2_y;
var tmp2_x = tmp0;
tmp2_y = tmp1;
var tmp3 = 4;
var tmp4 = 9;
var tmp5_y;
var tmp5_x = tmp3;
tmp5_y = tmp4;
var tmp6 = tmp2_x;
var tmp7 = tmp5_x;
var tmp_rn7 = tmp6 + tmp7;
var tmp8 = tmp2_y;
var tmp9 = tmp5_y;
var tmp_rn8 = tmp8 + tmp9;
var tmp10_y;
var tmp10_x = tmp_rn7;
tmp10_y = tmp_rn8;
var tmp11 = "(" + tmp10_x + "," + tmp10_y;
var tmp12 = ")";
tmp11 + tmp12;
```


## Should I use this?

Probably not (yet)
