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

record CommandOptions where
  constructor MkCommandOptions
  cwd : Maybe String
%runElab deriveJSON defaultOpts `{CommandOptions}

Show CommandOptions where
  show (MkCommandOptions cwd) =
    "MkCommandOptions \{show cwd}"

initOpts : CommandOptions
initOpts = MkCommandOptions Nothing

record Command where
  constructor MkCommand
  command : String
  args : List String
  options : CommandOptions
%runElab deriveJSON defaultOpts `{Command}

Show Command where
  show (MkCommand command args options) =
    "MkCommand \{show command} \{show args} \{show options}"

%foreign """
node:lambda:(cmd)=> { var x = JSON.parse(cmd); return function format(proc)
  { return JSON.stringify(
      { status: proc.status
      , stdout: proc.output[1].toString().substring(0, 1024)
      , stderr: proc.output[2].toString().substring(0, 1024)
      }
    );
  }(require('child_process').spawnSync(x.command, x.args, x.options))
}
"""
exec__prim : String -> PrimIO String
-- TODO error if substring > 1024

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

exec_internal : HasIO io => Command -> io String
exec_internal cmd =
  (primIO . exec__prim) (show $ toJSON cmd)

exec : HasIO io => Command -> io (Maybe Response)
exec str = do
  putStrLn $ show $ str
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
doBuild (MkPackage id repo ipkgFile) =
  let workdir = "./tmp/\{id}" in
  do
  lsRes <- exec $ MkCommand "ls" [] initOpts
  putStrLn $ show lsRes
  cloneRes <- exec $ MkCommand "git" (words "clone \{repo} \{workdir}") initOpts
  putStrLn $ show cloneRes
  buildRes <- exec $ MkCommand "idris2" (words "--install \{ipkgFile}") $ MkCommandOptions $ Just workdir
  putStrLn $ show buildRes

doBuild' : HasIO io => List Package -> io ()
doBuild' [] = pure ()
doBuild' (x :: xs) = do
  doBuild x
  doBuild' xs

main : IO ()
main = do
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
