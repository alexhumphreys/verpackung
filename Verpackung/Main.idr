module Verpackung.Main

import Verpackung.Derive.Derive
import Idrall.API.V2
import Language.JSON
import Language.Reflection
import System.File.ReadWrite
import System.File.Handle

%default covering

%language ElabReflection

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
  repo : String
  sha : Maybe String
-- %runElab (deriveFromDhall Record `{ PackageSetEntry })
%runElab deriveJSON defaultOpts `{PackageSetEntry}

Show PackageSetEntry where
  show (MkPackageSetEntry id repo sha) =
    "MkPackage \{show id} \{show repo} \{show sha}"

data PackageSetEntryStatus
  = Passing PackageSetEntry
  | Failing PackageSetEntry

Show PackageSetEntryStatus where
  show (Passing x) = "Passing \{show x}"
  show (Failing x) = "Failing \{show x}"

splitStatus : List PackageSetEntryStatus -> (List PackageSetEntry, List PackageSetEntry)
splitStatus [] = ([], [])
splitStatus (x :: xs) =
  let rest = splitStatus xs in
  case x of
       (Passing y) => (y :: fst rest, snd rest)
       (Failing y) => (fst rest, y :: snd rest)

doBuild : Package -> IOEither VerpackungError PackageSetEntryStatus
doBuild pkg@(MkPackage id repo ipkgFile depends) =
  let workdir = "./tmp/\{id}" in
  do
  lsRes <- exec $ MkCommand "ls" [] initOpts
  cleanup <- exec $ MkCommand "rm" (words "-rf \{workdir}") initOpts
  cloneRes <- exec $ MkCommand "git" (words "clone \{repo} \{workdir}") initOpts
  sha <- exec $ MkCommand "git" (words "-C \{workdir} rev-parse HEAD") initOpts
  copyDepends depends
  go $ buildRes workdir (stdout sha)
  where
    go : IO PackageSetEntryStatus -> IOEither VerpackungError PackageSetEntryStatus
    go x = MkIOEither $ do
      x' <- x
      pure $ pure $ x'
    buildRes : String -> String -> IO PackageSetEntryStatus
    buildRes workdir sha =
      case exec $ MkCommand "idris2" (words "--build \{ipkgFile}") $ MkCommandOptions $ Just workdir of
           (MkIOEither w) => do
             Right w' <- w | Left err => pure $ Failing $ MkPackageSetEntry id repo $ Just sha
             pure $ Passing $ MkPackageSetEntry id repo $ Just sha
    -- TODO copy transitive dependencies
    copyDepends : List String -> IOEither VerpackungError ()
    copyDepends [] = pure ()
    copyDepends (dep :: xs) =
      let depDir = "./tmp/\{id}/depends"
          fakeVersion = "0.10.0" -- TODO hack, need to parse this from ipkg file
      in
      do
        _ <- exec $ MkCommand "mkdir" (words "-p \{depDir}") initOpts
        _ <- exec $ MkCommand "cp" (words "-r ./tmp/\{dep}/build/ttc/ \{depDir}/\{dep}-\{fakeVersion}") initOpts
        copyDepends xs

go : List (Package, IOEither VerpackungError PackageSetEntryStatus) -> IO (List PackageSetEntryStatus)
go [] = pure []
go ((pkg, f) :: xs) = do
  Right res <- liftIOEither f
  | Left e => let this = Failing $ MkPackageSetEntry (id pkg) (repo pkg) Nothing in
    pure (this :: !(go xs))
  pure (res :: !(go xs))

getStdout : Command -> IO (Either VerpackungError String)
getStdout cmd = do
  Right res <- liftIOEither $ exec $ cmd
  | Left e => pure $ Left e
  pure $ pure $ trim $ stdout res

idrisVersion : IO (Either VerpackungError String)
idrisVersion = getStdout $ MkCommand "idris2" ["--version"] initOpts

date : IO (Either VerpackungError String)
date = getStdout $ MkCommand "date" ["+%Y%m%d"] initOpts

record IdrisVersion where
  constructor MkIdrisVersion
  version : String
%runElab deriveJSON defaultOpts `{IdrisVersion}

main : IO ()
main = do
  Right pkgs <- liftIOEither $ deriveFromDhallString {ty=PackageSet} "./package-set/packages.dhall"
  | Left e => putStrLn $ !(fancyError e)
  putStrLn $ show pkgs
  let xs = packages pkgs
  let pkgs = (map (\x=> (x, doBuild x)) xs)
  let final = go pkgs
  let split = splitStatus !final
  let date = !date
  let version = !idrisVersion
  putStrLn $ show split
  case (date, version) of
       (Left x, _) => putStrLn "failed to parse date"
       (Right x, Right y) =>
         let date' = trim x in
         do
         _ <- liftIOEither $ exec $ MkCommand "mkdir" (words "-p ./package-set/\{date'}") initOpts
         pass <- writeFile "./package-set/\{date'}/idris-version.json" (show $ toJSON $ MkIdrisVersion y)
         pass <- writeFile "./package-set/\{date'}/passing.json" (show $ toJSON $ fst split)
         fail <- writeFile "./package-set/\{date'}/failing.json" (show $ toJSON $ snd split)
         pure ()
       (_, Left y) => putStrLn "failed to parse idris version"
