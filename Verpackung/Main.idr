module Verpackung.Main

import Verpackung.Derive.Derive
import Idrall.API.V2
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
      , stdout: ""
      , stderr: ""
      }
    );
  }(require('child_process').spawnSync(cmd, [], {shell: true}))
}
"""
exec__prim : String -> PrimIO String
-- TODO ^^^ shell: true is unsafe!

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
  putStrLn $ str
  res <- exec_internal str
  putStrLn $ res
  pure $ parseResponse res

record Package where
  constructor MkPackage
  id : String
  repo : String
  ipkgFile : String
%runElab (deriveFromDhall Record `{ Package })

Show Package where
  show (MkPackage id repo ipkgFile) =
    "MkPackage \{show id} \{show repo} \{show ipkgFile}"

record PackageSet where
  constructor MkPackageSet
  packages : List Package
%runElab (deriveFromDhall Record `{ PackageSet })

Show PackageSet where
  show (MkPackageSet packages)  =
    "MkPackage \{show packages}"

doBuild : HasIO io => Package -> io ()
doBuild (MkPackage id repo ipkgFile) = do
  cloneRes <- exec "git clone \{repo} ./tmp/\{id}"
  putStrLn $ show cloneRes
  buildRes <- exec "cd ./tmp/\{id} && idris2 --install \{ipkgFile}"
  putStrLn $ show buildRes

doBuild' : HasIO io => List Package -> io ()
doBuild' [] = pure ()
doBuild' (x :: xs) = do
  doBuild x
  doBuild' xs

main : IO ()
main = do
  putStrLn $ !(echo "foo")
  putStrLn $ show !(exec "ls")
  Right pkgs <- liftIOEither $ deriveFromDhallString {ty=PackageSet} "./package-set/packages.dhall"
  | Left e => putStrLn $ !(fancyError e)
  putStrLn $ show pkgs
  let x = packages pkgs
  doBuild' x

{-
:exec main
foooo
{"status":0,"stdout":"Main.idr\nMain.idr~\nbuild\nsupport.js\n","stdrr":""}
-}
