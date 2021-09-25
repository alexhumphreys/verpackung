module Verpackung.Main

import Verpackung.Derive.Derive
import Language.JSON
import Language.Reflection

%language ElabReflection

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
      , stderr:proc.output[2].toString()
      }
    );
  }(require('child_process').spawnSync(cmd))
}
"""
exec__prim : String -> PrimIO String

record Response where
  constructor MkResponse
  status : Int
  stdout : String
  stderr : String

%runElab deriveJSON defaultOpts `{Response}

Show Response where
  show (MkResponse status stdout stderr) =
    "MkResponse \{show status} \{show stdout} \{show stderr}"

parseResponse : String -> Maybe Response
parseResponse x = do
  x' <- Language.JSON.parse x
  fromJSON x'

exec_internal : HasIO io => String -> io String
exec_internal =
  primIO . exec__prim

exec : HasIO io => String -> io (Maybe Response)
exec str = do
  res <- exec_internal str
  pure $ parseResponse res

main : IO ()
main = do
  putStrLn $ !(echo "foo")
  putStrLn $ show !(exec "ls")

{-
:exec main
foooo
{"status":0,"stdout":"Main.idr\nMain.idr~\nbuild\nsupport.js\n","stdrr":""}
-}
