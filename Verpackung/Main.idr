module Verpackung.Main

import Verpackung.Derive.Derive
import Idrall.API.V2
import Language.JSON
import Language.Reflection

%language ElabReflection

%foreign "node:lambda:(x)=>x+\"oo\""
echo__prim : String -> PrimIO String

export
echo : String -> IO String
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
node:lambda:(cmd)=> {
  var x = JSON.parse(cmd);
  return function format(proc) {
    if (proc.error) {
    return JSON.stringify(
      { error: proc.error.toString() }
    );
    } else {
      return JSON.stringify(
      { status: proc.status
      , stdout: proc.output[1].toString().substring(0, 1024)
      , stderr: proc.output[2].toString().substring(0, 1024)
      }
    );
    }
  }(require('child_process').spawnSync(x.command, x.args, x.options))
}
"""
exec__prim : String -> PrimIO String
-- TODO error if substring > 1024

record CommandError where
  constructor MkCommandError
  error : String
%runElab deriveJSON defaultOpts `{CommandError}

Show CommandError where
  show (MkCommandError error) =
    "MkResponse \{show error}"

record Response where
  constructor MkResponse
  status : Int
  stdout : String
  stderr : String
%runElab deriveJSON defaultOpts `{Response}

Show Response where
  show (MkResponse status stdout stderr) =
    "MkResponse \{show status} \{show stdout} \{show stderr}"

data VerpackungError
  = JSError CommandError
  | ShellError Response
  | ParseError String
  | OtherError String

Show VerpackungError where
  show (JSError x) = "JSError \{show x}"
  show (ShellError x) = "ShellError \{show x}"
  show (ParseError x) = "ParseError \{show x}"
  show (OtherError x) = "OtherError \{show x}"

parseResponse : String -> Either VerpackungError Response
parseResponse x =
  case Language.JSON.parse x of
       Nothing => Left $ ParseError x
       (Just json) => go json
where
  go : JSON -> Either VerpackungError Response
  go json =
    let err = fromJSON {a=CommandError} json
        res = fromJSON {a=Response} json
    in
    case (res, err) of
         ((Just r), Nothing) =>
            case status r of
                 0 => Right r
                 _ => Left $ ShellError r
         (Nothing, (Just e)) => Left $ JSError e
         _ => Left $ OtherError "Unknown response \{show json}"

exec_internal : Command -> IO String
exec_internal cmd =
  (primIO . exec__prim) (show $ toJSON cmd)

exec : Command -> IOEither VerpackungError Response
exec str = MkIOEither $
  do
  putStrLn $ show $ str
  res <- exec_internal str
  putStrLn $ res
  pure $ parseResponse res

record Package where
  constructor MkPackage
  id : String
  repo : String
  ipkgFile : String
  depends : List String
%runElab (deriveFromDhall Record `{ Package })

Show Package where
  show (MkPackage id repo ipkgFile depends) =
    "MkPackage \{show id} \{show repo} \{show ipkgFile} \{show depends}"

record PackageSet where
  constructor MkPackageSet
  packages : List Package
%runElab (deriveFromDhall Record `{ PackageSet })

Show PackageSet where
  show (MkPackageSet packages)  =
    "MkPackage \{show packages}"

record PackageSetEntry where
  constructor MkPackageSetEntry
  id : String
  sha : String
-- %runElab (deriveFromDhall Record `{ PackageSetEntry })

Show PackageSetEntry where
  show (MkPackageSetEntry id sha) =
    "MkPackage \{show id} \{show sha}"

data PackageSetEntryStatus
  = Passing PackageSetEntry
  | Failing PackageSetEntry VerpackungError

doBuild : Package -> IOEither VerpackungError PackageSetEntryStatus
doBuild (MkPackage id repo ipkgFile depends) =
  let workdir = "./tmp/\{id}" in
  do
  lsRes <- exec $ MkCommand "ls" [] initOpts
  cleanup <- exec $ MkCommand "rm" (words "-rf \{workdir}") initOpts
  cloneRes <- exec $ MkCommand "git" (words "clone \{repo} \{workdir}") initOpts
  sha <- exec $ MkCommand "git" (words "-C \{workdir} rev-parse HEAD") initOpts
  buildRes <- exec $ MkCommand "idris2" (words "--build \{ipkgFile}") $ MkCommandOptions $ Just workdir
  pure $ Passing $ MkPackageSetEntry id (stdout sha)

doBuild' : List Package -> IOEither VerpackungError PackageSetEntryStatus
doBuild' [] = liftEither $ Left $ OtherError "No package remaining"
doBuild' (x :: xs) = do
  _ <- doBuild x
  doBuild' xs

main : IO ()
main = do
  Right pkgs <- liftIOEither $ deriveFromDhallString {ty=PackageSet} "./package-set/packages.dhall"
  | Left e => putStrLn $ !(fancyError e)
  putStrLn $ show pkgs
  let xs = packages pkgs
  _ <- liftIOEither $ doBuild' xs -- TODO use traverse
  pure ()

{-
:exec main
foooo
{"status":0,"stdout":"Main.idr\nMain.idr~\nbuild\nsupport.js\n","stdrr":""}
-}
