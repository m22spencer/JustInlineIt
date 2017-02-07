package justInlineIt;

import haxe.macro.Expr;
import haxe.macro.Context in C;
using haxe.macro.ExprTools;
using Lambda;
using StringTools;

class JustInlineIt {
    macro public static function doIt(e:Expr) {
        var inlined = doOptimize(e);

        return @:privateAccess inlined;
    }

    //Do some repairs after converting a texpr back to an expr
    #if macro
    static function un_Impl_(e:Expr) {
        function go(e:Expr) {
            return switch(e) {
            /* TExprs erase abstracts, and instead use underlying types
            We rewrite to type as the base type instead of the fake abstract type.
            */
            case (macro var $name:$ct = $exp._new($a{args})) if (C.typeof(macro { var x:$ct; x; }).match(TAbstract(_, _))):
                var t = C.typeof(macro {var x:$ct; x; });
                switch(C.follow(t)) {
                case TAbstract(_.get() => t, []):
                    var nct = haxe.macro.TypeTools.toComplexType(t.type);
                    macro var $name:$nct = untyped $exp._new($a{args});
                case _:
                    throw "Impossible: " + t;
                }
            
            /* We need to rewrite the FooAbstract_Impl_ fields back to the real FooAbstract type
            */
            case (macro $e.$name) if (name.endsWith('_Impl_')):
                var unimplname = name.substr(0, name.indexOf('_Impl_'));
                macro @:pos(e.pos) $e.$unimplname;

            /* For js, `Std.int(n)` is converted to `n | 0`. We change it back
            */
            case (macro $n | 0):
                macro @:pos(e.pos) Std.int($n);
            case _:
                e.map(go);
            }
        }
        return go(e);
    }
    #end

    /** Make every variable declaration in `e` a unique name **/
    static function uniqueVars(e:Expr) {
        var tmp = 0;
        function go(e:Expr, varsMapping:Map<String,String>) {
            return switch(e) {
            case (macro $i{ident}) if (varsMapping.exists(ident)):
                macro @:pos(e.pos) $i{varsMapping.get(ident)};
            case {expr: EVars(vl)}:
                for (v in vl) {
                    var tid = 'tmp_rn${tmp++}';
                    if (v.expr != null) v.expr = go(v.expr, varsMapping);
                    varsMapping.set(v.name,tid);
                    v.name = tid;
                }
                { expr: EVars(vl), pos: e.pos };
            case macro $b{block}:
                var nm = [for (key in varsMapping.keys()) key => varsMapping.get(key)];
                macro @:pos(e.pos) $b{block.map(go.bind(_, nm))};
            case _:
                e.map(go.bind(_, varsMapping));
            }
        }

        return go(e, new Map());
    }

    /** Enforce initialization of variables
        `var x;
        ..code..;
        x = 99;`

        becomes
        `..code..;
        var x = 99;`
    **/
    static function alwaysInitialized(e:Expr) {
        var uninitialized = new Map();

        function go(e:Expr) {
            return switch(e) {
            case (macro var $name:$ct):
                uninitialized.set(name, ct);
                macro null;
            case (macro $i{name} = $expr) if (uninitialized.exists(name)):
                var ct = uninitialized.get(name);
                var res = macro @:pos(e.pos) var $name:$ct = $expr;
                uninitialized.remove(name);
                res;
            case _:
                e.map(go);
            }
        }
        return go(e);
    }

    /** Remove aliased temporary variables
        `var x = 10;
        var y = x;
        y;`

        becomes

        `var x = 10;
        x;`
    **/
    static function reduceTemps(e:Expr) {
        function go(e:Expr, varsMapping:Map<String,Expr>) {
            return switch(e) {
            case (macro var $name:$ct = ${e = {expr: EConst(CIdent(_))}}):
                varsMapping.set(name, e);
                macro null;
            case (macro var $name:$ct = cast ${e = {expr: EConst(CIdent(_))}}):
                //Remove casts, or haxe can't properly inline
                //We need to handle user explicit casts in a different way
                //Probably should not mutilate casts here

                #if DEBUG_JUST_INLINE_IT trace("svm: " + name); #end
                varsMapping.set(name, macro $e);
                macro null;
            case (macro $i{name}) if (varsMapping.exists(name)):
                go(macro @:pos(e.pos) ${varsMapping.get(name)}, varsMapping);
            case macro cast $x:
                //Remove casts, or haxe can't properly inline
                //We need to handle user explicit casts in a different way
                go(x, varsMapping);
            case _:
                e.map(go.bind(_, varsMapping));
            }
        }
        return go(alwaysInitialized(e), new Map());
    }
    
    #if macro
    static var tmpNum = 0;
    public static function doOptimize(e:Expr) {
        function optBody_(e:Expr) {
            var binds = [];

            function statement(e:Expr) {
                binds.push(e);
                return e;
            }

            function temporary(e:Expr) {
                return switch(e) {
                case macro $i{_}: e;
                case _:
                    var id = 'tmp' + tmpNum++;
                    binds.push(macro var $id = $e);
                    macro @:pos(e.pos) $i{id};
                }
            }

            function optBodyInternal(e:Expr) {
                return switch(e) {
                case {expr: EConst(_)}: e;
                case macro $b{block} if (block.length == 0): e;
                case macro {$e;}:
                    optBodyInternal(e);
                case macro $b{block}:
                    statement(optBodyInternal(block[0]));
                    optBodyInternal(macro $b{block.slice(1)});
                case macro new $tpath($a{args}):
                    var nargs = args.map(temporary);

                    var trxbody = macro @:pos(e.pos) new $tpath($a{nargs});
                    temporary(trxbody);
                // implement other ops
                case macro $a + $b:
                    var ta = temporary(a);
                    var tb = temporary(b);
                    macro @:pos(e.pos) $ta + $tb;
                case { expr: EWhile(cond, body, normalWhile) }:

                    { expr: EWhile(optBody_(cond), optBody_(body), normalWhile)
                    , pos : e.pos
                    };
                case { expr: ECall({ expr: EFunction(name, f)}, args) }:
                    function unReturn(e:Expr) {
                        function go(e:Expr) {
                            return switch(e) {
                            case macro return $v: macro @:pos(e.pos) rval = $v;
                            case { expr: EFunction(_, _) }: e;
                            case _: e.map(go);
                            }
                        }
                        return macro { var rval;
                                       ${go(e)};
                                       rval;
                                     };
                    }
                    //eta contraction
                    var tvars = args.map(optBodyInternal);
                    if (tvars.length != f.args.length)
                        throw "Type mismatch: Eta contraction";
                    var vdecls = [for (i in 0...tvars.length) {
                        var tvar  = tvars[i]; 
                        var nname = f.args[i].name;
                        var ntype = f.args[i].type;
                        macro var $nname:$ntype = $tvar;
                    }];
                    optBodyInternal(macro $b{vdecls.concat([unReturn(f.expr)])});
                case macro ($e):
                    optBodyInternal(e);
                case _:
                    e.map(optBodyInternal);
                }
            }

            var fBody = optBodyInternal(e);
            var newBody = macro @:privateAccess $b{binds.concat([fBody])};
            #if DEBUG_JUST_INLINE_IT trace('nb: ' + new haxe.macro.Printer().printExpr(newBody)); #end
            return newBody;
        }

        function texpr(e:Expr):Expr {
            var rexp = C.getTypedExpr(C.typeExpr(e));
            return rexp;
        }

        var texpanded = macro ${texpr(e)};
        #if DEBUG_JUST_INLINE_IT trace('texpanded: ' + new haxe.macro.Printer().printExpr(texpanded)); #end

        var tunique = uniqueVars(texpanded);
        #if DEBUG_JUST_INLINE_IT trace('tunique: ' + new haxe.macro.Printer().printExpr(tunique)); #end

        var newBody = optBody_(tunique);

        var newBody2 = reduceTemps(newBody);
        #if DEBUG_JUST_INLINE_IT trace('nbrt: ' + new haxe.macro.Printer().printExpr(newBody2)); #end

        var newUnimpld = un_Impl_(newBody2);
        #if DEBUG_JUST_INLINE_IT trace('nbrtx: ' + new haxe.macro.Printer().printExpr(newUnimpld)); #end

        return newUnimpld;
    }
    #end
}