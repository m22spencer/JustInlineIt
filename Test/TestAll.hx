package ;

import haxe.macro.Expr;
import haxe.macro.Context in C;
using TestData;

class TestAll {
    static function main() { test(); }
    @keep @:keep static function test() {
        opt( new Point(1,4).toString() );

        opt( (new Point(1,4) + new Point(4, 9)).toString() );

        opt( (new Point(1,4).yy + new Point(4, 9).xx).toString() );

        opt( (new Point(1,4).yy + new Point(new Point(3,5).x, 9).xx).toString() );

        opt({
            var pt = new Point(1,4);
            (pt + (pt.yy - pt)).toString();
        });

        opt({
            var arr = [for (x in SampleDataSet.floatArray) x];

            inline function mapUnboxed(arr:Array<Float>, f:Point->Point):Array<Float> {
                for (i in 0...arr.length>>>1) {
                    var np = f(new Point(arr[i*2], arr[i*2+1]));
                    arr[i*2]   = np.x;
                    arr[i*2+1] = np.y;
                }
                return arr;
            }

            mapUnboxed(arr, function(p) return p.xx - p.yy);
        });

        opt([].map(function(x) return x+1).map(function(y) return y*2));
    }

    macro static function opt(a:Expr) {
        var p = new haxe.macro.Printer().printExpr;

        var toRun = p(a);

        var OptTestMain =
            [ 'using TestData;'
            , 'import justInlineIt.JustInlineIt.doIt;'
            , 'class OptTestMain {'
            , '    static function main() {'
            , '        var a = ""+normal();'
            , '        var b = ""+justInlined();'
            , '        #if neko'
            , '        Sys.println(a + " ==? " + b);'
            , '        Sys.sleep(.001);'
            , '        Sys.exit(a == b ? 0 : 1);'
            , '        #end'
            , '    }'

            , '    static function normal() {'
            , '        return $toRun;'
            , '    }'

            , '    static function justInlined() {'
            , '        return doIt($toRun);'
            , '    }'

            , '}'
            ];

        sys.FileSystem.createDirectory("Bin");
        sys.io.File.saveContent('Bin/OptTestMain.hx', OptTestMain.join('\n'));

        var extra = '';
        #if DEBUG_JUST_INLINE_IT
        extra = ' -D DEBUG_JUST_INLINE_IT';
        #end

        var cmd = 'haxe -cp Bin -cp Test -cp Src -main OptTestMain';

        var exitCode = Sys.command('$cmd -neko Bin/OptTestMain.n $extra -cmd "neko Bin/OptTestMain.n"');
        if (exitCode != 0)
            C.warning('Test failed, results differ', C.currentPos());

        Sys.command('$cmd -js Bin/OptTestMain.js');
        var jsContents = sys.io.File.getContent('Bin/OptTestMain.js');

        var re = ~/^OptTestMain\.justInlined =/m;
        re.match(jsContents);
        var bodyStart = re.matchedPos().pos;

        var re = ~/^};?/m;
        re.matchSub(jsContents, bodyStart);
        var bodyEnd = re.matchedPos().pos + re.matchedPos().len;

        var body = jsContents.substr(bodyStart, bodyEnd-bodyStart);

        if (~/new /.match(body)) {
            C.warning('TestFailed, not all allocations were removed', C.currentPos());
            Sys.println(body);
        }

        sys.FileSystem.deleteFile('Bin/OptTestMain.hx');
        sys.FileSystem.deleteFile('Bin/OptTestMain.js');
        sys.FileSystem.deleteFile('Bin/OptTestMain.n');

        return macro null;
    }
}