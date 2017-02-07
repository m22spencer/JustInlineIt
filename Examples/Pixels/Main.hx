package ;

import haxe.io.Bytes;
import justInlineIt.JustInlineIt.doIt;

// Currently required since TExprs aren't subject to public/private
//@:access(haxe.io.Bytes)
class Main {
    static function main() {
        doIt({
            var pixels = new Pixels(256*256*4);

            pixels.foo();

            for (i in 0...pixels.length) {
                var c = pixels[i];
                c.r = .5;
                pixels[i] = c;
            }
        });
    }
}

abstract Pixels(Bytes) {
    public function new(size:Int) this = haxe.io.Bytes.alloc(size);

    @:arrayAccess
    public inline function get(idx:Int) {
        var offset = idx * 4;
        return new Color( this.get(offset)   / 0xFF
                        , this.get(offset+1) / 0xFF
                        , this.get(offset+2) / 0xFF
                        , this.get(offset+3) / 0xFF
                        );
    }

    @:arrayAccess
    public inline function set(idx:Int, color:Color) {
        var offset = idx * 4;
        this.set(offset  , Std.int(color.a * 0xFF));
        this.set(offset+1, Std.int(color.r * 0xFF));
        this.set(offset+2, Std.int(color.g * 0xFF));
        this.set(offset+3, Std.int(color.b * 0xFF));
    }

    public function foo() {
        return "hello";
    }

    public var length(get,never):Int;
    public inline function get_length() return this.length >>> 2;
}

class Color {
    public var a:Float;
    public var r:Float;
    public var g:Float;
    public var b:Float;
    inline public function new(a, r, g, b) {
        this.a = a;
        this.r = r;
        this.g = g;
        this.b = b;
    }
}