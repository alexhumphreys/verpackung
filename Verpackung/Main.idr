module Verpackung.Main

import Verpackung.Derive.Derive
import Verpackung.Command
import Idrall.API.V2
import Language.JSON
import Language.Reflection
import System.File.ReadWrite
import System.File.Handle

%default covering
%hide Idrall.IOEither.IOEither -- TODO could be dodgy
%language ElabReflection

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

doBuild : Package -> IOEither VerpackungError PackageSetEntryStatus
doBuild pkg@(MkPackage id repo ipkgFile depends) =
  let workdir = "./tmp/\{id}" in
  do
  cleanup <- exec $ MkCommand "rm" (words "-rf \{workdir}") initOpts
  cloneRes <- exec $ MkCommand "git" (words "clone \{repo} \{workdir}") initOpts
  sha <- exec $ MkCommand "git" (words "-C \{workdir} rev-parse HEAD") initOpts
  copyDepends depends
  liftIO $ buildRes workdir (trim $ stdout sha)
  where
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

record IdrisVersion where
  constructor MkIdrisVersion
  version : String
%runElab deriveJSON defaultOpts `{IdrisVersion}

writePackageSetToFS : String -> String -> (List PackageSetEntry, List PackageSetEntry) -> IO ()
writePackageSetToFS date version (passing, failing) =
  let packageSetDir = "./package-set/\{date}" in
  do
  _ <- liftIOEither $ exec $ MkCommand "mkdir" (words "-p \{packageSetDir}") initOpts
  putStrLn $ show version
  _ <- writeFile "\{packageSetDir}/idris-version.json" (show $ toJSON $ MkIdrisVersion version)
  putStrLn "Passing: \{show $ length passing}"
  putStrLn $ show passing
  _ <- writeFile "\{packageSetDir}/passing.json" (show $ toJSON $ passing)
  putStrLn "Failing: \{show $ length failing}"
  putStrLn $ show failing
  _ <- writeFile "\{packageSetDir}/failing.json" (show $ toJSON $ failing)
  putStrLn "Passing: \{show $ length passing}, Failing: \{show $ length failing}"
  pure ()

main : IO ()
main = do
  Right packageSet <- readPackagesDhall | Left e => putStrLn $ !(fancyError e)
  putStrLn $ show packageSet
  let xs = packages packageSet
  let pkgs = (map (\x=> (x, doBuild x)) xs)
  let final = go pkgs
  let split = splitStatus !final
  let date = !date
  let version = !idrisVersion
  case (date, version) of
       (Right date', Right version') =>
          writePackageSetToFS (trim date') version' split
       (Left x, _) => putStrLn "failed to parse date"
       (_, Left y) => putStrLn "failed to parse idris version"
  where
    readPackagesDhall : IO (Either Error PackageSet)
    readPackagesDhall = liftIOEither $ deriveFromDhallString {ty=PackageSet} "./package-set/packages.dhall"
    splitStatus : List PackageSetEntryStatus -> (List PackageSetEntry, List PackageSetEntry)
    splitStatus [] = ([], [])
    splitStatus (x :: xs) =
      let rest = splitStatus xs in
      case x of
           (Passing y) => (y :: fst rest, snd rest)
           (Failing y) => (fst rest, y :: snd rest)
    idrisVersion : IO (Either VerpackungError String)
    idrisVersion = getStdout $ MkCommand "idris2" ["--version"] initOpts
    date : IO (Either VerpackungError String)
    date = getStdout $ MkCommand "date" ["+%Y%m%d"] initOpts

