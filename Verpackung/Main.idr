module Verpackung.Main

%foreign "node:lambda:(x)=>x+\"oo\""
echo__prim : String -> PrimIO String

export
echo : HasIO io => String -> io String
echo =
  primIO . echo__prim

%foreign """
node:lambda:(cmd)=> { return function format(proc)
  { return JSON.stringify(
      { status: proc.status
      , stdout:proc.output[1].toString()
      , stdrr:proc.output[2].toString()
      }
    );
  }(require('child_process').spawnSync(cmd))
}
"""
exec__prim : String -> PrimIO String

export
exec : HasIO io => String -> io String
exec =
  primIO . exec__prim

main : IO ()
main = do
  putStrLn $ !(echo "foo")
  putStrLn $ !(exec "ls")

{-
:exec main
foooo
{"status":0,"stdout":"Main.idr\nMain.idr~\nbuild\nsupport.js\n","stdrr":""}
-}
