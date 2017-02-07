class SampleDataSet {
    public static var floatArray = [for(i in 0...10) Math.random()];
}

class PointInternal {
    public var x:Float;
    public var y:Float;
    inline public function new (x:Float = 1.0, y:Float = 1.0) {
        this.x = x;
        this.y = y;
    }

    inline public function toString() {
        return '($x,$y)';
    }
}

abstract Point(PointInternal) {
    public var x(get,never):Float;
    inline function get_x() return this.x;
    public var y(get,never):Float;
    inline function get_y() return this.y;

    public var yx(get,never):Point;
    inline function get_yx() return new Point(this.y, this.x);

    public var xx(get,never):Point;
    inline function get_xx() return new Point(this.x, this.x);

    public var yy(get,never):Point;
    inline function get_yy() return new Point(this.y, this.y);

    public inline function self() return this;
    
    inline public function new(x = 1.0, y = 1.0) {
        this = new PointInternal(x, y);
    }

    @:op(a + b)
    inline static function opAdd(a:Point, b:Point) {
            var as = a.self();
            var bs = b.self();
            return new Point(as.x + bs.x, as.y + bs.y);
    }

    @:op(a - b)
    inline static function opSub(a:Point, b:Point) {
            var as = a.self();
            var bs = b.self();
            return new Point(as.x - bs.x, as.y - bs.y);
    }

    inline public function toString() {
        return '(${this.x},${this.y})';
    }
}
