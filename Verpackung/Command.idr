module Verpackung.Command

import Verpackung.Derive.Derive
import public Verpackung.IOEither

import Data.String
import Language.JSON
import Language.Reflection

import System.File.ReadWrite
import System.File.Handle

%default total

%language ElabReflection

public export
record CommandOptions where
  constructor MkCommandOptions
  cwd : Maybe String
%runElab deriveJSON defaultOpts `{CommandOptions}

public export
Show CommandOptions where
  show (MkCommandOptions cwd) =
    "MkCommandOptions \{show cwd}"

public export
initOpts : CommandOptions
initOpts = MkCommandOptions Nothing

public export
record Command where
  constructor MkCommand
  command : String
  args : List String
  options : CommandOptions
%runElab deriveJSON defaultOpts `{Command}

public export
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

public export
record CommandError where
  constructor MkCommandError
  error : String
%runElab deriveJSON defaultOpts `{CommandError}

public export
Show CommandError where
  show (MkCommandError error) =
    "MkResponse \{show error}"

public export
record Response where
  constructor MkResponse
  status : Int
  stdout : String
  stderr : String
%runElab deriveJSON defaultOpts `{Response}

public export
Show Response where
  show (MkResponse status stdout stderr) =
    "MkResponse \{show status} \{show stdout} \{show stderr}"

public export
data VerpackungError
  = JSError CommandError
  | ShellError Response
  | ParseError String
  | OtherError String

public export
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

public export
exec : Command -> IOEither VerpackungError Response
exec str = MkIOEither $
  do
  putStrLn $ show $ str
  res <- exec_internal str
  putStrLn $ res
  pure $ parseResponse res

public export
getStdout : Command -> IO (Either VerpackungError String)
getStdout cmd = do
  Right res <- liftIOEither $ exec $ cmd
  | Left e => pure $ Left e
  pure $ pure $ trim $ stdout res

