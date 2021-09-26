var foreign = function foo(cmd) {
  var x = JSON.parse(cmd);
  return function format(proc) {
    console.log(proc);
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

var result = foreign(JSON.stringify({command: "lss", args: [], options: {}}));
//console.log(JSON.stringify(x.substring(0, 1025)));

console.log(result);

var y = {};
if (y.error) {
  console.log("then");
} else {
  console.log("else");
}

/*
node:lambda:(cmd)=> { var x = JSON.parse(cmd); return function format(proc)
  { console.log(proc); return JSON.stringify(
      { status: proc.status
      , stdout: proc.output[1].toString().substring(0, 1024)
      , stderr: proc.output[2].toString().substring(0, 1024)
      }
    );
  }(require('child_process').spawnSync(x.command, x.args, x.options))
}
*/

// const timer = ms => new Promise( res => setTimeout(res, ms));
// console.log("wait 3 seconds")
// timer(6000).then(_=>console.log("done"));
// console.log(x)

